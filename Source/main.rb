require_relative "Service/members_service"
require_relative "Service/pulls_service"
require_relative "Service/reviews_service"
require_relative "Model/user_reviews"
require 'dotenv'
require 'thread'

class Main
	def initialize
		Dotenv.load('./.env')
		@reviews_needed_for_each_pr = 5
		@weeks_searched = Integer(ENV['WEEKS_TO_SEARCH'])
		@number_of_cores = Integer(ENV['NUMBER_OF_THREADS'])

		token = ENV['GITHUB_KEY']
		@reviews_service = ReviewsService.new(token)
		@members_service = MembersService.new(token)
		@pulls_service = PullRequestsService.new(token)

		@user_reviews_list = []
		@pull_requests = []
		@pull_requests_reviews_list = []
		@days_until_approve_list = []

		@output_name = "ios_reviews_list.txt"

		run(ENV['IS_BITRISE'])
	end

	def run(is_bitrise)
		fetch_reviews_for_all_members

		fetch_pull_requests

		fetch_all_reviews

		@user_reviews_list = @user_reviews_list.sort_by(&:qtd).reverse

		# To expose all users
		show_user_review_list

		save_list

		if is_bitrise == 'true'
			export_list_to_envman
			save_top_10_list
		end
	end

	def fetch_reviews_for_all_members
		puts("Fetching users...")
		members = @members_service.members

		# Ignore some users (maybe new users?)
		users_to_ignore = ["mobilepicpay"]
		queue = members.clone

		threads = (0..@number_of_cores).map do
			Thread.new do
				member = queue.pop
				while member
					# Ignore the members in users_to_ignore list
					if !users_to_ignore.include?(member.login)
						@user_reviews_list.append(UserReviews.new(member))
					end
					member = queue.pop
				end
			end
		end
		threads.each { |t| t.join }

		puts("Found #{@user_reviews_list.length} users!")
		puts("")
	end

	def fetch_pull_requests
		puts("Fetching pull requests...")

		total_days = @weeks_searched * 7

		i = 0
		loop do
			temp_pulls = @pulls_service.pull_requests(i)
			i += 1

			# Find if there is an element that was created before the period we want
			index = temp_pulls.each_index.detect { |a| 
				created_at = temp_pulls[a].created_at
				days_interval = Integer(Date.today - created_at)
				days_interval > total_days
			}

			# Remove the elements that were created before the period we want
			if !index.nil?
				temp_pulls = temp_pulls[0...index]
			end

			# Remove other invalid PRs
			temp_pulls = temp_pulls.select { |item| item.valid }

			@pull_requests.concat(temp_pulls)

			break if !index.nil?
		end

		puts("Found #{@pull_requests.length} pull requests!")
		puts("")
	end

	def fetch_all_reviews
		puts("Fetching reviews...")
		queue = @pull_requests.clone
		threads = (0..@number_of_cores).map do
			Thread.new do
				pr = queue.pop
				while pr
					fetch_reviews(pr)
					pr = queue.pop
					sleep(0.3)
				end
			end
		end

		threads.each { |t| t.join }
		puts("")
	end

	def fetch_reviews(pr)
		puts("Fetching review for PR: #{pr.number}")
		reviews = @reviews_service.reviews(pr.number)

		# Ignore pull requests with lots of reviews
		return if reviews.count > 20

		get_time_to_approve_small_prs(pr, reviews)

		for review in reviews
			# Find the user reviews list for the user that created that review
			user_reviews = @user_reviews_list.detect { |item| item.user.id == review.user.id }
			if !user_reviews.nil?
				# Increment the count for the number of reviews made by that user
				user_reviews.update
			end
		end

		@pull_requests_reviews_list.append(PullRequestsReviews.new(pr, reviews.length))
	end

	def get_time_to_approve_small_prs(pr, reviews)
		return if reviews.count < 5

		reviews.sort_by(&:date)

		# Get the last review date
		date = reviews[4].date

		# Get how many days until we had 5 reviews
		days_until_approve = Integer(date - pr.created_at)

		# Ignore if there was too much time until approve (draft pr?)
		return if days_until_approve > 10

		details = @pulls_service.pull_request(pr.number)

		# If it was a small pr, add the time we needed to have 5 reviews to the list
		if details.total_size <= 400
			@days_until_approve_list.append(days_until_approve)
		end
	end

	def show_user_review_list
		for user_reviews in @user_reviews_list
			puts("#{user_reviews.user.login} - #{user_reviews.qtd}")
		end
		puts("")
	end

	def save_list
		File.open("#{@output_name}", "w") { |f|
			f.write("#{Date.today}\n\n")
			for user_reviews in @user_reviews_list
				f.write("#{user_reviews.user.login} - #{user_reviews.qtd}\n")
			end
			f.write("\n")

			days_until_approve_medium = @days_until_approve_list.sum.to_f / @days_until_approve_list.count.to_f
			f.write("Média de dias para aprovar PRs pequenos: #{days_until_approve_medium}\n")

			done_reviews = @user_reviews_list.map(&:qtd).compact.sum
			needed_reviews = @pull_requests.length.to_f * @reviews_needed_for_each_pr

			f.write("PRS totais: #{@pull_requests.length}\n")
			f.write("Fizemos #{done_reviews} reviews\n")
			f.write("Precisamos de #{needed_reviews} reviews\n")

			missing_reviews = needed_reviews - done_reviews
			f.write("Faltaram #{missing_reviews} reviews\n")

			medium_reviews_done_by_user = done_reviews / @user_reviews_list.length
			f.write("Tivemos uma média de #{medium_reviews_done_by_user} reviews por usuário\n")

			medium_reviews_needed_by_user = needed_reviews / @user_reviews_list.length
			f.write("A média para que todos os PRs estivesse fechados seria #{medium_reviews_needed_by_user}\n")

			users_on_average = (@user_reviews_list.select { |item| item.qtd >= medium_reviews_needed_by_user }).count
			users_bellow_average = @user_reviews_list.count - users_on_average
			f.write("Temos #{users_on_average} pessoas dentro da média\n")
			f.write("E #{users_bellow_average} pessoas abaixo\n")

			medium_reviews_needed_by_user_weekly = medium_reviews_needed_by_user / @weeks_searched
			medium_reviews_done_by_user_weekly = medium_reviews_done_by_user / @weeks_searched
			f.write("Semanalmente precisamos de #{medium_reviews_needed_by_user_weekly} reviews por usuário\n")
			f.write("Estamos fazendo #{medium_reviews_done_by_user_weekly}\n")

			f.close_write
		}
	end

	def export_list_to_envman
		system( "envman add --key OUTPUT_REVIEWS_IOS --value '#{@output_name}'" )
	end

	def save_top_10_list
		IO.popen('envman add --key OUTPUT_TOP_10', 'r+') {|f|
			f.write("#{Date.today}\n\n")
			for i in 0..9 do
				user_reviews = @user_reviews_list[i]
			    f.write("#{user_reviews.user.login} - #{user_reviews.qtd}\n")
			end
			f.close_write
		}
	end
end

@main = Main.new

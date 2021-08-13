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
		@weeks_searched = 3
		@number_of_cores = 1

		token = ENV['GITHUB_KEY']
		@reviews_service = ReviewsService.new(token)
		@members_service = MembersService.new(token)
		@pulls_service = PullRequestsService.new(token)

		@user_reviews_list = []
		@pull_requests = []
		@pull_requests_reviews_list = []

		run
	end

	def run
		fetch_reviews_for_all_members

		fetch_pull_requests

		fetch_all_reviews

		@user_reviews_list = @user_reviews_list.sort_by(&:qtd)

		# To expose all users
		show_user_review_list

		result
	end

	def fetch_reviews_for_all_members
		puts("Fetching users...")
		members = @members_service.members

		users_to_ignore = ["mobilepicpay"]
		queue = members.clone
		threads = (0..@number_of_cores).map do
			Thread.new do
				member = queue.pop
				while member
					if !users_to_ignore.include?(member.login)
						@user_reviews_list.append(UserReviews.new(member))
					end
					member = queue.pop
				end
			end
		end
		threads.each { |t| t.join }

		puts("Found #{@user_reviews_list.length} users!")
	end

	def fetch_pull_requests
		puts("Fetching pull requests...")
		total_days = @weeks_searched * 7

		i = 0
		loop do
			temp_pulls = @pulls_service.pull_requests(i)
			i += 1

			index = temp_pulls.each_index.detect { |i| 
				created_at = temp_pulls[i].created_at
				(Date.today - created_at) > total_days
			}

			if !index.nil?
				temp_pulls = temp_pulls[0...index]
			end

			temp_pulls = temp_pulls.select { |item| item.valid }

			@pull_requests.concat(temp_pulls)

			break if !index.nil?
		end

		puts("Found #{@pull_requests.length} pull requests!")
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
				end
			end
		end

		threads.each { |t| t.join }
	end

	def fetch_reviews(pr)
		reviews = @reviews_service.reviews(pr.number)
		reviews = reviews.uniq { |item| [ item.user.id ] }
		reviews = reviews.select { |item| item.user.id != pr.user.id }

		# Ignore pull requests with lots of reviews
		return if reviews.count > 7

		for review in reviews
			user_reviews = @user_reviews_list.detect { |item| item.user.id == review.user.id }
			if !user_reviews.nil?
				user_reviews.update
			end
		end

		@pull_requests_reviews_list.append(PullRequestsReviews.new(pr, reviews.length))
	end

	def show_user_review_list
		for user_reviews in @user_reviews_list
			puts("#{user_reviews.user.login} - QTD: #{user_reviews.qtd}")
		end
	end

	def result
		done_reviews = @user_reviews_list.map(&:qtd).compact.sum
		needed_reviews = @pull_requests.length.to_f * @reviews_needed_for_each_pr

		puts("PRS totais: #{@pull_requests.length}")
		puts("Fizemos #{done_reviews} reviews")
		puts("Precisamos de #{needed_reviews} reviews")

		missing_reviews = needed_reviews - done_reviews
		puts("Faltaram #{missing_reviews} reviews")

		medium_reviews_done_by_user = done_reviews / @user_reviews_list.length
		puts("Tivemos uma média de #{medium_reviews_done_by_user} reviews por usuário")

		medium_reviews_needed_by_user = needed_reviews / @user_reviews_list.length
		puts("A média para que todos os PRs estivesse fechados seria #{medium_reviews_needed_by_user}")

		users_on_average = (@user_reviews_list.select { |item| item.qtd >= medium_reviews_needed_by_user }).count
		users_bellow_average = @user_reviews_list.count - users_on_average
		puts("Temos #{users_on_average} pessoas dentro da média")
		puts("E #{users_bellow_average} pessoas abaixo")

		medium_reviews_needed_by_user_weekly = medium_reviews_needed_by_user / @weeks_searched
		medium_reviews_done_by_user_weekly = medium_reviews_done_by_user / @weeks_searched
		puts("Semanalmente precisamos de #{medium_reviews_needed_by_user_weekly} reviews por usuário")
		puts("Estamos fazendo #{medium_reviews_done_by_user_weekly}")
	end
end

@main = Main.new

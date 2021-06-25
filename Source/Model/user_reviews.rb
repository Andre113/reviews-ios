class UserReviews
	attr_reader :user, :qtd

	def initialize(user)
		@user = user
		@qtd = 0
	end

	def update
		@qtd += 1
	end
end

class PullRequestsReviews
	attr_reader :pullRequest, :qtd

	def initialize(pullRequest, qtd)
		@pullRequest = pullRequest
		@qtd = qtd
	end
end
class PullRequestDetails
	attr_reader :additions, :deletions

	def initialize(json)
		@additions = Integer(json["additions"])
		@deletions = Integer(json["deletions"])
	end

	def total_size
		additions + deletions
	end
end
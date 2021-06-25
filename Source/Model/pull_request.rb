class PullRequest
	attr_reader :number, :created_at, :closed_at, :merged_at, :user

	def initialize(json)
		@number = json["number"]
		@created_at = Date.parse(json["created_at"])
		@closed_at = json["closed_at"]
		@merged_at = json["merged_at"]
		@user = User.new(json["user"])
	end

	def valid
		is_old = (Date.today - @created_at) > 1

		was_merged = !@merged_at.nil?
		is_open = @merged_at.nil? && @closed_at.nil?

		(was_merged || is_open) && is_old
	end
end
require_relative "user"

class Review
	attr_reader :user, :date

	def initialize(json)
		@user = User.new(json["user"])
		@date = Date.parse(json["submitted_at"])
	end
end
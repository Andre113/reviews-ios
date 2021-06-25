require_relative "user"

class Review
	attr_reader :user

	def initialize(json)
		@user = User.new(json["user"])
	end
end
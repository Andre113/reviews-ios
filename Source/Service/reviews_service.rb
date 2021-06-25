require 'dotenv'
require 'rest-client'
require 'JSON'
require_relative '../Model/review'

class ReviewsService
	attr_reader :token, :base_url

	def initialize(token)
		@token = token
		team = ENV['GITHUB_TEAM']
		repo = ENV['GITHUB_REPO']
		@base_url = "https://api.github.com/repos/#{team}/#{repo}/pulls/"
	end

	def headers
		{
		'Accept': 'application/vnd.github.v3+json',
		'Content-type': 'application/json',
		'Authorization': "token #{token}"
		}
	end

	def reviews(number)
		url = @base_url + "#{number}/reviews"
		request = RestClient.get(url, headers)
		data = JSON.parse(request.body)
		reviews = data.map { |item| Review.new(item) }
	end
end
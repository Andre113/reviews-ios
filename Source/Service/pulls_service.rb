require 'dotenv'
require 'rest-client'
require 'JSON'
require_relative '../Model/pull_request.rb'

class PullRequestsService
	attr_reader :token, :base_url

	def initialize(token)
		@token = token
		team = ENV['GITHUB_TEAM']
		repo = ENV['GITHUB_REPO']
		@base_url = "https://api.github.com/repos/#{team}/#{repo}/pulls"
	end

	def headers(page)
		{
			'Accept': 'application/vnd.github.v3+json',
			'Content-type': 'application/json',
			'Authorization': "token #{@token}",
			'params': {
				page: page,
				state: "all",
				sort: "created",
				direction: "desc"
			}
		}
	end

	def pull_requests(page)
		request = RestClient.get(@base_url, headers(page))

		data = JSON.parse(request.body)
		repos = data.map { |item| PullRequest.new(item) }
	end
end
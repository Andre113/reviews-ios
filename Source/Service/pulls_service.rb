require 'dotenv'
require 'rest-client'
require 'JSON'
require_relative '../Model/pull_request.rb'
require_relative '../Model/pull_request_details.rb'

class PullRequestsService
	attr_reader :token, :base_url

	def initialize(token)
		@token = token
		team = ENV['GITHUB_TEAM']
		repo = ENV['GITHUB_REPO']
		@base_url = "https://api.github.com/repos/#{team}/#{repo}/pulls"
	end

	def list_headers(page)
		{
			'Accept': 'application/vnd.github.v3+json',
			'Content-type': 'application/json',
			'Authorization': "token #{@token}",
			'params': {
				page: page,
				state: "all",
				sort: "created",
				direction: "desc",
				per_page: 100
			}
		}
	end

	def details_header
		{
			'Accept': 'application/vnd.github.v3+json',
			'Content-type': 'application/json',
			'Authorization': "token #{@token}",
		}
	end

	def pull_requests(page)
		request = RestClient.get(@base_url, list_headers(page))

		data = JSON.parse(request.body)
		repos = data.map { |item| PullRequest.new(item) }
	end

	def pull_request(pull_number)
		url = "#{@base_url}/#{pull_number}"
		request = RestClient.get(url, details_header)

		data = JSON.parse(request.body)
		PullRequestDetails.new(data)
	end
end
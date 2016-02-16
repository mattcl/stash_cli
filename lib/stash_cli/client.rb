require 'rest-client'
require 'uri'
require 'json'
require 'configatron'

require 'stash_cli/pull_request'

module StashCLI
  class Client
    BASE_API_URL = 'rest/api/1.0'

    attr_reader :server, :resource

    def initialize(server, auth_token)
      @server = URI(server)
      @resource = RestClient::Resource.new(
        File.join(@server.to_s, BASE_API_URL),
        headers: {
          authorization: "Basic #{auth_token}",
          accept: :json,
          content_type: :json
        })
    end

    def users
      response = resource['users?limit=1000'].get
      JSON.parse(response.body)['values']
    end

    def repositories(project)
      response = resource["projects/#{project}/repos?limit=1000"].get
      JSON.parse(response.body)
    end

    def pull_request(options={})
      params = {
        title: options[:title],
        fromRef: {
          id: "refs/heads/#{options[:from_branch]}",
          repository: {
            slug: options[:from_slug],
            project: {
              key: options[:project]
            }
          }
        },
        toRef: {
          id: "refs/heads/#{options[:target_branch]}",
          repository: {
            slug: options[:target_slug],
            project: {
              key: options[:project]
            }
          }
        },
        reviewers: []
      }

      if options[:reviewers].any?
        params[:reviewers] = options[:reviewers].map do |name|
          {
            user: {
              name: name
            }
          }
        end
      end

      params[:description] = options[:description] if options[:description]

      path = "projects/#{options[:project]}/repos/#{options[:target_slug]}/pull-requests"

      response = resource[path].post(params.to_json)

      PullRequest.from_response(JSON.parse(response.body), server.to_s)
    end
  end
end

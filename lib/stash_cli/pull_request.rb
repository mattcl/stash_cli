module StashCLI
  class PullRequest
    attr_reader :id, :url

    def self.from_response(response, base_url)
      id = response['id']
      url = response['links']['self'].first['href']
      PullRequest.new(id, url)
    end

    def initialize(id, url)
      @id = id
      @url = url
    end
  end
end

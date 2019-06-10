# rubocop:disable Rails/TimeZone
module GithubMetrics
  class PullRequest
    extend Forwardable

    class << self
      def fetch_recent_pull_requests
        github_client.pull_requests(
          '18f/identity-idp',
          per_page: 100,
          state: :all,
          accept: 'application/vnd.github.shadow-cat-preview+json',
        ).map do |pr_response|
          new(pr_response)
        end
      end

      def fetch_pull_requests_for_sprint(sprint)
        fetch_recent_pull_requests.select do |pull_request|
          sprint.includes_pull_request?(pull_request)
        end
      end

      def github_client
        @github_client ||= Octokit::Client.new
      end
    end

    def initialize(pull_request_response)
      @pull_request_response = pull_request_response
    end

    def_delegators :pull_request_response, :title, :created_at, :closed_at,
                   :merged_at, :number, :draft

    def ready_for_review_at
      events = self.class.github_client.issue_events(
        '18f/identity-idp', number, accept: 'application/vnd.github.mockingbird-preview'
      )
      events.select do |item|
        item.event == 'ready_for_review'
      end.first&.created_at || created_at
    end

    def done_at_or_current_date
      merged_at || closed_at || Time.now
    end

    def ready_for_review_time
      done_at_or_current_date - ready_for_review_at
    end

    private

    attr_reader :pull_request_response
  end
end
# rubocop:enable Rails/TimeZone

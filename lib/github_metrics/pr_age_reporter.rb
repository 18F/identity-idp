require 'octokit'
require 'date'

module GithubMetrics
  class PrAgeReporter
    attr_reader :tot

    # rubocop:disable Rails/Output
    def call
      numerator = 0
      sprint_pull_requests.each do |pr|
        ready_for_review_time = pr.ready_for_review_time
        numerator += ready_for_review_time
        puts "'#{pr.title}' under review for #{seconds_to_hours(ready_for_review_time)} hours"
      end
      puts "Average: #{seconds_to_hours(numerator / sprint_pull_requests.count.to_f)} hours"
    end
    # rubocop:enable Rails/Output

    private

    def sprint_pull_requests
      @sprint_pull_requests ||= PullRequest.fetch_pull_requests_for_sprint(Sprint.new)
    end

    def seconds_to_hours(seconds)
      (seconds / 3600).round
    end
  end
end

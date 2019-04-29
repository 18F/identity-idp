require 'octokit'
require 'date'

module GithubMetrics
  class PrAgeReporter
    def call
      numerator = 0; denominator = 0;
      sprint_pull_requests.each do |pr|
        pr_open_seconds = (pr.closed_at || pr.merged_at || Time.now).to_i - pr.created_at.to_i
        numerator += pr_open_seconds
        denominator += 1.0
        puts "'#{pr.title}' open for #{seconds_to_hours(pr_open_seconds)} hours"
      end
      puts "Average: #{seconds_to_hours(numerator / denominator)} hours"
    end

    def sprint_start
      @sprint_start ||= begin
        reference_sprint_start = Date.new(2019, 4, 22)
        days_since_reference = Date.today - reference_sprint_start
        sprints_since_reference = (days_since_reference / 14).floor
        (reference_sprint_start + 14 * sprints_since_reference).to_time
      end
    end

    def sprint_end
      (sprint_start + 14).to_time
    end

    def pr_open_in_current_sprint?(pr)
      closed_at_or_current_time = pr.closed_at || pr.merged_at || Time.now
      return true if pr.created_at > sprint_start || closed_at_or_current_time > sprint_start
      false
    end

    def sprint_pull_requests
      github_client.pull_requests('18f/identity-idp', per_page: 100, state: :all).select do |pr|
        pr_open_in_current_sprint?(pr)
      end
    end

    def github_client
      @github_client = Octokit::Client.new
    end

    def seconds_to_hours(value)
      (value / 3600.0).round
    end
  end
end

# rubocop:disable Rails/TimeZone
module GithubMetrics
  class Sprint
    attr_reader :sprint_start

    def initialize(sprint_start: nil)
      @sprint_start = sprint_start
      @sprint_start ||= current_sprint_start
    end

    def sprint_end
      sprint_start + 14 * 24 * 3600
    end

    def includes_pull_request?(pull_request)
      return false if pull_request.draft
      created_at = pull_request.created_at
      return true if created_at < sprint_end && created_at > sprint_start
      done_at_or_current_date = pull_request.done_at_or_current_date
      return true if done_at_or_current_date < sprint_end && done_at_or_current_date > sprint_start
      false
    end

    private

    def current_sprint_start
      @sprint_start ||= begin
        # 12:00 ET on 7/2/2019 was the start of sprint 88
        reference_sprint_start = Time.new(2019, 7, 2, 12, 0, 0, -14_400)
        days_since_reference = (Time.now - reference_sprint_start) / (24 * 3600)
        sprints_since_reference = (days_since_reference / 14).floor
        reference_sprint_start + 14 * sprints_since_reference * 24 * 3600
      end
    end
  end
end
# rubocop:enable Rails/TimeZone

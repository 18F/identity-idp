require 'login_gov/hostdata'

module Reports
  class UspsReport < BaseReport
    REPORT_NAME = 'usps-report'.freeze

    def initialize
      @results = {}
      @results[:today] = Time.zone.now
      @results[:letters_sent_since_days] = {}
      @results[:letters_sent_and_validated_since_days] = {}
      @results[:percent_sent_and_validated_since_days] = {}
    end

    def call
      create_reports
      save_report(REPORT_NAME, @results.to_json)
      @results.to_json
    end

    private

    def create_reports
      [7, 14, 30, 60, 90, 10_000].each do |days_ago|
        sent = letters_sent_since(days_ago)
        validated = letters_sent_and_validated_since(days_ago)
        @results[:percent_sent_and_validated_since_days][days_ago] =
           validated.zero? ? 0 : (validated * 100.0 / sent).round(2)
      end
    end

    def letters_sent_since(days_ago)
      @results[:letters_sent_since_days][days_ago] =
         Db::UspsConfirmationCode::LettersSentSince.call(days_ago.days.ago)
    end

    def letters_sent_and_validated_since(days_ago)
      @results[:letters_sent_and_validated_since_days][days_ago] =
         Db::UspsConfirmationCode::LettersSentAndVerifiedSince.call(days_ago.days.ago)
    end
  end
end

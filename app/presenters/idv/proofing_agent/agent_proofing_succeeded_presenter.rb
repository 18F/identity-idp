# frozen_string_literal: true

module Idv
  module ProofingAgent
    class AgentProofingSucceededPresenter
      include Rails.application.routes.url_helpers

      attr_reader :verified_at_string, :url_options

      # Per ticket: EOD Samoa Standard Time (UTC-11) + 2 days so the
      # displayed date covers all U.S. timezones (-11 to +10).
      def self.deadline_for(verified_at:)
        Time.zone.parse(verified_at).in_time_zone('Etc/GMT+5').end_of_day + 2.days
      end

      def initialize(verified_at:, url_options:)
        @verified_at_string = verified_at
        @url_options = url_options
      end

      def confirmation_url
        new_user_session_url
      end

      def contact_us_url
        MarketingSite.contact_url
      end

      def change_password_url
        edit_user_password_url
      end

      def deadline
        self.class.deadline_for(verified_at: @verified_at_string)
      end

      def verified_at
        Time.zone.parse(@verified_at_string).in_time_zone('American Samoa')
      end
    end
  end
end

# frozen_string_literal: true

module Idv
  module ProofingAgent
    class AgentProofingSucceededPresenter
      include Rails.application.routes.url_helpers

      attr_reader :verified_at_string, :url_options, :service_provider

      # Per analysis linked on ticket: EOD UTC-5 + 2 days provides the best
      # coverage over all U.S. timezones (-11 to +10). +10 will be correct after 3pm local.
      PARSE_TIME_ZONE = 'Etc/GMT+5'

      def self.deadline_for(verified_at:)
        Time.zone.parse(verified_at).in_time_zone(PARSE_TIME_ZONE).end_of_day + validity_hours
      end

      def self.validity_hours
        IdentityConfig.store.agent_proofed_user_time_validity_hours.hours
      end

      def initialize(verified_at:, url_options:, service_provider: nil)
        @verified_at_string = verified_at
        @url_options = url_options
        @service_provider = service_provider
      end

      def confirmation_url
        if IdentityConfig.store.idv_proofing_agent_confirmation_url.present?
          return IdentityConfig.store.idv_proofing_agent_confirmation_url
        end

        service_provider_homepage_url || new_user_session_url
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
        Time.zone.parse(@verified_at_string).in_time_zone(PARSE_TIME_ZONE)
      end

      private

      def service_provider_homepage_url
        sp_return_url_resolver.homepage_url if service_provider
      end

      def sp_return_url_resolver
        SpReturnUrlResolver.new(service_provider: service_provider)
      end
    end
  end
end

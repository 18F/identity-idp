# frozen_string_literal: true

module DataRequests
  module Deployed
    class CreateUserReport
      attr_reader :user, :requesting_issuers

      def initialize(user, requesting_issuers = nil)
        @user = user
        @requesting_issuers = requesting_issuers
      end

      def call
        {
          user_id: user.id,
          login_uuid: user.uuid,
          requesting_issuer_uuid: requesting_issuer_uuid,
          email_addresses: email_addresses_report,
          mfa_configurations: mfa_configurations_report,
          user_events: user_events_report,
        }
      end

      private

      def email_addresses_report
        CreateEmailAddressesReport.new(user).call
      end

      def mfa_configurations_report
        CreateMfaConfigurationsReport.new(user).call
      end

      def requesting_issuer_uuid
        return user.uuid if requesting_issuers.blank?
        user.agency_identities.where(agency: requesting_agencies).first&.uuid ||
          "NonSPUser##{user.id}"
      end

      def requesting_agencies
        ServiceProvider.where(issuer: requesting_issuers).map(&:agency).uniq
      end

      def user_events_report
        CreateUserEventsReport.new(user).call
      end
    end
  end
end

# frozen_string_literal: true

module DataRequests
  module Deployed
    class CreateMfaConfigurationsReport
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def call
        {
          phone_configurations: phone_configurations_report,
          auth_app_configurations: auth_app_configurations_report,
          webauthn_configurations: webauthn_configurations_report,
          piv_cac_configurations: piv_cac_configurations_report,
          backup_code_configurations: backup_code_configurations_report,
        }
      end

      private

      def auth_app_configurations_report
        user.auth_app_configurations.map do |auth_app_configuration|
          {
            name: auth_app_configuration.name,
            created_at: auth_app_configuration.created_at,
          }
        end
      end

      def backup_code_configurations_report
        user.backup_code_configurations.map do |backup_code_configuration|
          {
            created_at: backup_code_configuration.created_at,
            used_at: backup_code_configuration.used_at,
          }
        end
      end

      def phone_configurations_report
        user.phone_configurations.map do |phone_configuration|
          {
            phone: phone_configuration.phone,
            created_at: phone_configuration.created_at,
            confirmed_at: phone_configuration.confirmed_at,
          }
        end
      end

      def piv_cac_configurations_report
        user.piv_cac_configurations.map do |piv_cac_configuration|
          {
            name: piv_cac_configuration.name,
            created_at: piv_cac_configuration.created_at,
          }
        end
      end

      def webauthn_configurations_report
        user.webauthn_configurations.map do |webauthn_configuration|
          {
            name: webauthn_configuration.name,
            created_at: webauthn_configuration.created_at,
          }
        end
      end
    end
  end
end

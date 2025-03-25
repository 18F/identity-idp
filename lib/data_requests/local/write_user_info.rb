# frozen_string_literal: true

require 'csv'

module DataRequests
  module Local
    class WriteUserInfo
      attr_reader :user_report, :csv

      def initialize(user_report:, csv:, include_header: false)
        @user_report = user_report
        @csv = csv
        @include_header = include_header
      end

      def include_header?
        !!@include_header
      end

      def call
        if include_header?
          csv << %w[
            uuid
            type
            value
            created_at
            confirmed_at
            internal_id
          ]
        end

        write_not_found
        write_emails
        write_phone_configurations
        write_auth_app_configurations
        write_webauthn_configurations
        write_piv_cac_configurations
        write_backup_code_configurations
      end

      private

      def uuid
        user_report[:requesting_issuer_uuid]
      end

      def write_not_found
        if user_report[:not_found]
          csv << [
            uuid,
            'not found',
          ]
        end
      end

      def write_auth_app_configurations
        user_report[:mfa_configurations][:auth_app_configurations].each do |auth_app_config|
          csv << [
            uuid,
            'Auth app configuration',
            auth_app_config[:name],
            auth_app_config[:created_at],
          ]
        end
      end

      def write_backup_code_configurations
        user_report[:mfa_configurations][:backup_code_configurations].each do |backup_code_config|
          csv << [
            uuid,
            'Backup code configuration',
            nil,
            backup_code_config[:created_at],
            backup_code_config[:used_at],
          ]
        end
      end

      def write_emails
        user_report[:email_addresses].each do |email|
          csv << [
            uuid,
            'Email',
            email[:email],
            email[:created_at],
            email[:confirmed_at],
          ]
        end
      end

      def write_phone_configurations
        user_report[:mfa_configurations][:phone_configurations].each do |phone_config|
          csv << [
            uuid,
            'Phone configuration',
            phone_config[:phone],
            phone_config[:created_at],
            phone_config[:confirmed_at],
            phone_config[:id],
          ]
        end
      end

      def write_piv_cac_configurations
        user_report[:mfa_configurations][:piv_cac_configurations].each do |piv_cac_config|
          csv << [
            uuid,
            'PIV/CAC configuration',
            piv_cac_config[:name],
            piv_cac_config[:created_at],
          ]
        end
      end

      def write_webauthn_configurations
        user_report[:mfa_configurations][:webauthn_configurations].each do |webauthn_config|
          csv << [
            uuid,
            'WebAuthn configuration',
            webauthn_config[:name],
            webauthn_config[:created_at],
          ]
        end
      end
    end
  end
end

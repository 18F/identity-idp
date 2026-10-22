# frozen_string_literal: true

module AccountRecovery
  # Called inside the password-verification transaction. Do not delete credentials
  # here: the user has not yet verified a replacement.
  class SuspendExistingMfa
    CONFIGURATION_ASSOCIATIONS = %i[
      phone_configurations auth_app_configurations webauthn_configurations
      piv_cac_configurations backup_code_configurations
    ].freeze

    def initialize(account_recovery_request:)
      @account_recovery_request = account_recovery_request
    end

    def call
      account_recovery_request.with_lock do
        return false unless account_recovery_request.state ==
                            AccountRecoveryRequest::PASSWORD_VERIFIED

        CONFIGURATION_ASSOCIATIONS.each do |association|
          user.public_send(association).update_all(
            account_recovery_request_id: account_recovery_request.id,
          )
        end
        user.direct_otp = nil
        user.direct_otp_sent_at = nil
        user.remember_device_revoked_at = Time.zone.now
        user.save!
        account_recovery_request.transition_to!(AccountRecoveryRequest::REPLACEMENT_MFA_PENDING)
      end
    end

    private

    attr_reader :account_recovery_request

    def user
      account_recovery_request.user
    end
  end
end

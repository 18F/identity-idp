# frozen_string_literal: true

module AccountRecovery
  # Enrollment calls this only after proving possession of a new credential.
  # Delete the request's suspended set, never every credential on the account.
  class CompleteReplacementMfa
    ASSOCIATIONS_BY_AUTH_METHOD = {
      'sms' => :phone_configurations,
      'voice' => :phone_configurations,
      'totp' => :auth_app_configurations,
      'webauthn' => :webauthn_roaming_configurations,
      'webauthn_platform' => :webauthn_platform_configurations,
      'piv_cac' => :piv_cac_configurations,
      'backup_code' => :backup_code_configurations,
    }.freeze

    def initialize(account_recovery_request:, auth_method:)
      @account_recovery_request = account_recovery_request
      @auth_method = auth_method
    end

    def call
      account_recovery_request.with_lock do
        return false unless account_recovery_request.replacement_mfa_pending?
        return false unless replacement_present?

        SuspendExistingMfa::CONFIGURATION_ASSOCIATIONS.each do |association|
          user.public_send(association)
            .where(account_recovery_request_id: account_recovery_request.id).each(&:destroy!)
        end
        account_recovery_request.transition_to!(AccountRecoveryRequest::COMPLETED)
      end
    end

    private

    attr_reader :account_recovery_request, :auth_method

    def user
      account_recovery_request.user
    end

    def replacement_present?
      association = ASSOCIATIONS_BY_AUTH_METHOD[auth_method]
      association && MfaContext.new(user).public_send(association).any?(&:mfa_enabled?)
    end
  end
end

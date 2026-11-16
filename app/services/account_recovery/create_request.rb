# frozen_string_literal: true

module AccountRecovery
  class CreateRequest
    include AccountRecoveryConcern

    INELIGIBLE = :ineligible
    REQUEST_NOT_PERSISTED = :request_not_persisted

    attr_reader :account_recovery_request

    # @param user [User]
    def initialize(user:)
      @user = user
    end

    def call
      # Eligibility is re-checked here rather than trusted from the page that
      # rendered the link.
      return failure(INELIGIBLE) if !EligibilityPolicy.new(user: user).eligible?

      @account_recovery_request = create_request

      return failure(REQUEST_NOT_PERSISTED) if account_recovery_request.blank?

      notify_user_by_email
      telephony_response = notify_user_by_sms_if_applicable

      FormResponse.new(
        success: true,
        extra: {
          recovery_state: account_recovery_request.state,
          telephony_response: telephony_response&.to_h,
          **RequestAnalyticsAttributes.new(user: user).call,
        },
      )
    end

    private

    attr_reader :user

    def notify_user_by_email
      UserMailer.with(user: user, email_address: user.last_sign_in_email_address)
        .account_recovery_request.deliver_now_or_later
    end

    def failure(reason)
      FormResponse.new(
        success: false,
        errors: { base: [reason.to_s] },
      )
    end

    def notify_user_by_sms_if_applicable
      phone = MfaContext.new(user).phone_configurations.take&.phone
      return unless phone

      response = Telephony.send_account_recovery_notice(
        to: phone,
        country_code: Phonelib.parse(phone).country,
        interval: account_recovery_wait_period_interval,
      )
      if !response.success? && response.error.is_a?(Telephony::OptOutError)
        PhoneNumberOptOut.mark_opted_out(phone)
      end
      response
    end

    def create_request
      user.with_lock do
        next unless EligibilityPolicy.new(user: user).eligible?

        request = AccountRecoveryRequest.create!(
          user: user,
          state: AccountRecoveryRequest::REQUESTED,
          requested_at: Time.zone.now,
        )

        raise ActiveRecord::Rollback if !request.wait!

        request
      end
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end

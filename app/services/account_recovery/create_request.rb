# frozen_string_literal: true

module AccountRecovery
  class CreateRequest
    INELIGIBLE = :ineligible
    REQUEST_NOT_PERSISTED = :request_not_persisted

    # The created record, available to callers after a successful #call.
    # @return [AccountRecoveryRequest, nil]
    attr_reader :account_recovery_request

    # @param user [User]
    def initialize(user:)
      @user = user
    end

    # @return [FormResponse]
    def call
      # Eligibility is re-checked here rather than trusted from the page that
      # rendered the link.
      return failure(INELIGIBLE) if !EligibilityPolicy.new(user: user).eligible?

      @account_recovery_request = create_request

      return failure(REQUEST_NOT_PERSISTED) if account_recovery_request.blank?

      notify_user_by_email

      FormResponse.new(
        success: true,
        extra: { recovery_state: account_recovery_request.state },
      )
    end

    private

    attr_reader :user

    def notify_user_by_email
      UserMailer.with(user: user, email_address: user.last_sign_in_email_address)
        .account_recovery_request.deliver_now_or_later
    end

    # @param reason [Symbol] bounded, non-PII reason safe for analytics
    # @return [FormResponse]
    def failure(reason)
      FormResponse.new(
        success: false,
        errors: { base: [reason.to_s] },
      )
    end

    def create_request
      user.with_lock do
        request = AccountRecoveryRequest.create!(
          user: user,
          state: AccountRecoveryRequest::REQUESTED,
          requested_at: Time.zone.now,
        )

        # A request that cannot reach the waiting state is not usable, so fail
        # closed rather than leaving a stranded row behind.
        raise ActiveRecord::Rollback if !request.wait!

        request
      end
    rescue ActiveRecord::RecordNotUnique
      # Another request for this user became active between the eligibility
      # check and the insert.
      nil
    end
  end
end

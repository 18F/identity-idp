# frozen_string_literal: true

module AccountRecovery
  # Cancels a user's unredeemed recovery request and notifies the confirmed
  # sign-in address. A request past link redemption is left alone: it stays in
  # flight until replacement MFA is added.
  class CancelRequest
    # State of the request before it was cancelled, for analytics.
    attr_reader :recovery_state

    # @param user [User]
    # @param reason [String] one of the AccountRecoveryRequest::CANCEL_REASON_* values
    def initialize(user:, reason:)
      @user = user
      @reason = reason
    end

    # @return [Boolean] whether a request was cancelled
    def call
      request = AccountRecoveryRequest.active_for_user(user)
      return false if request.blank?

      cancelled = request.with_lock do
        next false unless request.awaiting_link_redemption?

        @recovery_state = request.state
        request.cancel!(reason:)
      end
      return false unless cancelled
      UserMailer.with(user: user, email_address: user.last_sign_in_email_address)
        .account_recovery_cancelled.deliver_now_or_later
      true
    end

    private

    attr_reader :user, :reason
  end
end

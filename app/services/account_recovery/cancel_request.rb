# frozen_string_literal: true

module AccountRecovery
  class CancelRequest
    def initialize(user:)
      @user = user
    end

    def call
      request = AccountRecoveryRequest.active_for_user(user)
      return false unless request&.cancel!

      UserMailer.with(user: user, email_address: user.last_sign_in_email_address)
        .account_recovery_cancelled.deliver_now_or_later
      true
    end

    private

    attr_reader :user
  end
end

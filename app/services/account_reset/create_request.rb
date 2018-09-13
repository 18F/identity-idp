module AccountReset
  class CreateRequest
    def initialize(user)
      @user = user
    end

    def call
      create_request
      notify_user_by_email
      notify_user_by_sms_if_applicable
    end

    private

    attr_reader :user

    def create_request
      request = AccountResetRequest.find_or_create_by(user: user)
      request.update!(
        request_token: SecureRandom.uuid,
        requested_at: Time.zone.now,
        cancelled_at: nil,
        granted_at: nil,
        granted_token: nil
      )
    end

    def notify_user_by_email
      UserMailer.account_reset_request(user).deliver_later
    end

    def notify_user_by_sms_if_applicable
      phone = user.phone_configurations.first&.phone
      return unless phone
      SmsAccountResetNotifierJob.perform_now(
        phone: phone,
        token: user.account_reset_request.request_token
      )
    end
  end
end

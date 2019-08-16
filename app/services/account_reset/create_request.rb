module AccountReset
  class CreateRequest
    def initialize(user)
      @user = user
    end

    def call
      request = create_request
      notify_user_by_email(request)
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
        granted_token: nil,
      )
      request
    end

    def notify_user_by_email(request)
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.account_reset_request(email_address, request).deliver_later
      end
    end

    def notify_user_by_sms_if_applicable
      phone = MfaContext.new(user).phone_configurations.take&.phone
      return unless phone
      cancel_link = Rails.application.routes.url_helpers.account_reset_cancel_url(
        token: user.account_reset_request.request_token,
      )
      Telephony.send_account_reset_notice(to: phone, cancel_link: cancel_link)
    end
  end
end

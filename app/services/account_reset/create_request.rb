module AccountReset
  class CreateRequest
    def initialize(user)
      @user = user
    end

    def call
      request = create_request
      notify_user_by_email(request)
      notify_user_by_sms_if_applicable

      FormResponse.new(
        success: true,
        extra: extra_analytics_attributes,
      )
    end

    private

    attr_reader :user

    def create_request
      request = AccountResetRequest.create_or_find_by(user: user)
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
        UserMailer.with(user: user, email_address: email_address).account_reset_request(request).
          deliver_now_or_later
      end
    end

    def notify_user_by_sms_if_applicable
      phone = MfaContext.new(user).phone_configurations.take&.phone
      return unless phone
      @telephony_response = Telephony.send_account_reset_notice(
        to: phone,
        country_code: Phonelib.parse(phone).country,
      )
    end

    def extra_analytics_attributes
      @telephony_response&.extra&.slice(:request_id, :message_id) || {}
    end
  end
end

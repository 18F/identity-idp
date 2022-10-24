module AccountReset
  class Cancel
    include ActiveModel::Model
    include CancelTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      if success
        notify_user_via_email_of_account_reset_cancellation
        notify_user_via_phone_of_account_reset_cancellation if phone.present?
        update_account_reset_request
      end

      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success, :token

    def notify_user_via_email_of_account_reset_cancellation
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).account_reset_cancel.
          deliver_now_or_later
      end
    end

    def notify_user_via_phone_of_account_reset_cancellation
      @telephony_response = Telephony.send_account_reset_cancellation_notice(
        to: phone,
        country_code: Phonelib.parse(phone).country,
      )
    end

    def update_account_reset_request
      account_reset_request.update!(
        cancelled_at: Time.zone.now,
        request_token: nil,
        granted_token: nil,
      )
    end

    def user
      account_reset_request&.user || AnonymousUser.new
    end

    def phone
      MfaContext.new(user).phone_configurations.take&.phone
    end

    def extra_analytics_attributes
      @telephony_response.to_h.merge(
        user_id: user.uuid,
      )
    end
  end
end

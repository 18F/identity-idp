module Accounts
  # Lets users generate a new personal key
  class PersonalKeysController < ReauthnRequiredController
    include PersonalKeyConcern

    before_action :confirm_two_factor_authenticated
    before_action :prompt_for_password_if_pii_locked

    def new
      analytics.profile_personal_key_visit
    end

    def create
      user_session[:personal_key] = create_new_code
      analytics.profile_personal_key_create
      create_user_event(:new_personal_key)
      result = send_new_personal_key_notifications
      analytics.profile_personal_key_create_notifications(**result.to_h)

      flash[:info] = t('account.personal_key.old_key_will_not_work')
      redirect_to manage_personal_key_url
    end

    private

    def prompt_for_password_if_pii_locked
      return unless pii_locked?
      redirect_to capture_password_url
    end

    def pii_locked?
      UserDecorator.new(current_user).identity_verified? &&
        !Pii::Cacher.new(current_user, user_session).exists_in_session?
    end

    # @return [FormResponse]
    def send_new_personal_key_notifications
      emails = current_user.confirmed_email_addresses.map do |email_address|
        UserMailer.with(user: current_user, email_address: email_address).personal_key_regenerated.
          deliver_now_or_later
      end

      telephony_responses = MfaContext.new(current_user).
        phone_configurations.map do |phone_configuration|
        phone = phone_configuration.phone
        Telephony.send_personal_key_regeneration_notice(
          to: phone,
          country_code: Phonelib.parse(phone).country,
        )
      end

      form_response(emails: emails, telephony_responses: telephony_responses)
    end

    def form_response(emails:, telephony_responses:)
      FormResponse.new(
        success: true,
        extra: {
          emails: emails.count,
          sms_message_ids: telephony_responses.map { |resp| resp.to_h[:message_id] },
        },
      )
    end
  end
end

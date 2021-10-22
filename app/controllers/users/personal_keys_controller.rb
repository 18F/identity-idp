module Users
  class PersonalKeysController < ApplicationController
    include PersonalKeyConcern
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override, only: :show

    def show
      personal_key = user_session[:personal_key]

      analytics.track_event(
        Analytics::PERSONAL_KEY_VIEWED, personal_key_present: personal_key.present?
      )

      return redirect_to account_url if personal_key.blank?

      @code = personal_key
    end

    def update
      user_session.delete(:personal_key)
      redirect_to next_step
    end

    def create
      user_session[:personal_key] = create_new_code
      analytics.track_event(Analytics::PROFILE_PERSONAL_KEY_CREATE)
      create_user_event(:new_personal_key)
      result = send_new_personal_key_notifications
      analytics.track_event(Analytics::PROFILE_PERSONAL_KEY_CREATE_NOTIFICATIONS, result.to_h)
      redirect_to manage_personal_key_url
    end

    private

    def next_step
      if user_needs_to_reactivate_account?
        reactivate_account_url
      elsif session[:sp] && user_has_not_visited_any_sp_yet?
        sign_up_completed_url
      else
        after_sign_in_path_for(current_user)
      end
    end

    def user_has_not_visited_any_sp_yet?
      current_user.identities.pluck(:last_authenticated_at).compact.empty?
    end

    # @return [FormResponse]
    def send_new_personal_key_notifications
      emails = current_user.confirmed_email_addresses.map do |email_address|
        UserMailer.personal_key_regenerated(current_user, email_address.email).deliver_now_or_later
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

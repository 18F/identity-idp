module Users
  class PhoneConfirmationController < ApplicationController
    include PhoneConfirmationFlow

    before_action :authenticate_user!
    before_action :check_for_unconfirmed_phone

    def show
      @code_value = confirmation_code if FeatureManagement.prefill_otp_codes?
      @unconfirmed_phone = unconfirmed_phone
      @reenter_phone_number_path = if current_user.phone.present?
                                     profile_path
                                   else
                                     phone_setup_path
                                   end
    end

    private

    def this_phone_confirmation_path
      phone_confirmation_path(
        otp_method: current_otp_method
      )
    end

    def this_send_confirmation_code_path(otp_method)
      phone_confirmation_send_path(otp_method: otp_method)
    end

    def confirmation_code_session_key
      :phone_confirmation_code
    end

    def unconfirmed_phone_session_key
      :unconfirmed_phone
    end

    def assign_phone
      @updating_existing_number = old_phone.present?

      if @updating_existing_number
        phone_changed
      else
        phone_confirmed
      end

      current_user.update(phone: unconfirmed_phone, phone_confirmed_at: Time.current)
    end

    def old_phone
      current_user.phone
    end

    def phone_changed
      create_user_event(:phone_changed)
      analytics.track_event('User changed their phone number')
      SmsSenderNumberChangeJob.perform_later(old_phone)
    end

    def phone_confirmed
      create_user_event(:phone_confirmed)
      analytics.track_event('User confirmed their phone number')
    end

    def after_confirmation_path
      if @updating_existing_number
        profile_path
      elsif decorated_user.should_acknowledge_recovery_code?(session)
        settings_recovery_code_url
      else
        after_sign_in_path_for(current_user)
      end
    end
  end
end

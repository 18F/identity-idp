module Users
  class PhoneConfirmationController < ApplicationController
    before_action :authenticate_user!
    before_action :check_for_unconfirmed_mobile

    def show
      analytics.track_pageview

      @code_value = confirmation_code if FeatureManagement.prefill_otp_codes?
      @unconfirmed_mobile = unconfirmed_mobile
      @reenter_phone_number_path = if current_user.mobile.present?
                                     edit_user_registration_path
                                   else
                                     phone_setup_path
                                   end
    end

    def send_code
      send_confirmation_code
      redirect_to phone_confirmation_path
    end

    def confirm
      if params['code'] == confirmation_code
        analytics.track_event('User confirmed their phone number')
        process_valid_code
      else
        analytics.track_event('User entered invalid phone confirmation code')
        process_invalid_code
      end
    end

    def self.generate_confirmation_code
      digits = Devise.direct_otp_length
      random_base10(digits)
    end

    def self.random_base10(digits)
      SecureRandom.random_number(10**digits).to_s.rjust(digits, '0')
    end

    private

    def process_invalid_code
      flash[:error] = t('errors.invalid_confirmation_code')
      redirect_to phone_confirmation_path
    end

    def set_mobile_number
      @updating_existing_number = current_user.mobile.present?
      if @updating_existing_number
        analytics.track_event('User changed and confirmed their phone number')
        SmsSenderNumberChangeJob.perform_later(current_user.mobile)
      end
      current_user.update(mobile: unconfirmed_mobile, mobile_confirmed_at: Time.current)
    end

    def process_valid_code
      set_mobile_number
      clear_session_data

      flash[:success] = t('notices.phone_confirmation_successful')
      redirect_to after_confirmation_path
    end

    def after_confirmation_path
      if @updating_existing_number
        profile_path
      else
        after_sign_in_path_for(current_user)
      end
    end

    def check_for_unconfirmed_mobile
      redirect_to root_path unless unconfirmed_mobile
    end

    def send_confirmation_code
      # Generate a new confirmation code only if there isn't already one set in the
      # user's session. Re-sending the confirmation code doesn't generate a new one.
      if confirmation_code.nil?
        self.confirmation_code = PhoneConfirmationController.generate_confirmation_code
      end

      SmsSenderConfirmationJob.perform_later(confirmation_code, unconfirmed_mobile)
    end

    def confirmation_code=(code)
      user_session[:phone_confirmation_code] = code
    end

    def confirmation_code
      user_session[:phone_confirmation_code]
    end

    def unconfirmed_mobile
      user_session[:unconfirmed_mobile]
    end

    def clear_session_data
      user_session.delete(:unconfirmed_mobile)
      user_session.delete(:phone_confirmation_code)
    end
  end
end

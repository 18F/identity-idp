module Idv
  class PhoneConfirmationController < ApplicationController
    include PhoneConfirmationFlow
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :check_for_unconfirmed_phone

    def show
      @code_value = confirmation_code if FeatureManagement.prefill_otp_codes?
      @unconfirmed_phone = unconfirmed_phone
      @reenter_phone_number_path = idv_sessions_path
    end

    private

    def this_phone_confirmation_path
      idv_phone_confirmation_path
    end

    def confirmation_code_session_key
      :idv_phone_confirmation_code
    end

    def unconfirmed_phone_session_key
      :idv_unconfirmed_phone
    end

    def assign_phone
      if current_active_profile && unconfirmed_phone != current_active_profile.phone
        log_phone_change
      end
      idv_params['phone_confirmed_at'] = Time.current
    end

    def current_active_profile
      current_user.active_profile
    end

    def log_phone_change
      old_phone = current_active_profile.phone
      analytics.track_event('User changed and confirmed their verified phone number')
      SmsSenderNumberChangeJob.perform_later(old_phone)
    end

    def after_confirmation_path
      idv_questions_path
    end
  end
end

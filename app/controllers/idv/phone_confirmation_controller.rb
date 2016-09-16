module Idv
  class PhoneConfirmationController < ApplicationController
    include PhoneConfirmationFlow
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :check_for_unconfirmed_phone

    def show
      @code_value = confirmation_code if FeatureManagement.prefill_otp_codes?
      @unconfirmed_phone = unconfirmed_phone
      @reenter_phone_number_path = idv_session_path
    end

    private

    def this_phone_confirmation_path
      idv_phone_confirmation_path(otp_method: current_otp_method)
    end

    def this_send_confirmation_code_path(otp_method)
      idv_phone_confirmation_send_path(otp_method: otp_method)
    end

    def confirmation_code_session_key
      :idv_phone_confirmation_code
    end

    def unconfirmed_phone_session_key
      :idv_unconfirmed_phone
    end

    def assign_phone
      analytics.track_event('User confirmed their verified phone number')
      idv_session.params['phone_confirmed_at'] = Time.current
    end

    def after_confirmation_path
      idv_questions_path
    end
  end
end

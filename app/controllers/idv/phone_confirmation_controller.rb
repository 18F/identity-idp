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
      idv_phone_confirmation_path(delivery_method: current_otp_delivery_method)
    end

    def this_send_confirmation_code_path(delivery_method)
      idv_phone_confirmation_send_path(delivery_method: delivery_method)
    end

    def confirmation_code_session_key
      :idv_phone_confirmation_code
    end

    def unconfirmed_phone_session_key
      :idv_unconfirmed_phone
    end

    def assign_phone
      analytics.track_event('User confirmed their verified phone number')
      idv_params['phone_confirmed_at'] = Time.current
    end

    def after_confirmation_path
      idv_questions_path
    end
  end
end

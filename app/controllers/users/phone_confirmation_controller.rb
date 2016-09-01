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
        delivery_method: current_otp_delivery_method
      )
    end

    def this_send_confirmation_code_path(delivery_method)
      phone_confirmation_send_path(delivery_method: delivery_method)
    end

    def confirmation_code_session_key
      :phone_confirmation_code
    end

    def unconfirmed_phone_session_key
      :unconfirmed_phone
    end

    def assign_phone
      old_phone = current_user.phone
      @updating_existing_number = old_phone.present?
      if @updating_existing_number
        analytics.track_event('User changed their phone number')
        SmsSenderNumberChangeJob.perform_later(old_phone)
      else
        analytics.track_event('User confirmed their phone number')
      end
      current_user.update(phone: unconfirmed_phone, phone_confirmed_at: Time.current)
    end

    def after_confirmation_path
      if @updating_existing_number
        profile_path
      else
        after_sign_in_path_for(current_user)
      end
    end
  end
end

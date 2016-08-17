module Users
  class EditPhoneController < ApplicationController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated

    def edit
      @update_user_phone_form = UpdateUserPhoneForm.new(current_user)
    end

    def update
      @update_user_phone_form = UpdateUserPhoneForm.new(current_user)

      if @update_user_phone_form.submit(user_params)
        process_updates
        bypass_sign_in current_user
      else
        render :edit
      end
    end

    private

    def user_params
      params.require(:update_user_phone_form).permit(:phone, :sms_otp_delivery)
    end

    def process_updates
      analytics.track_event('User asked to update their phone number') if
        @update_user_phone_form.phone_changed?

      if @update_user_phone_form.require_phone_confirmation?
        flash[:notice] = t('devise.registrations.phone_update_needs_confirmation')
        prompt_to_confirm_phone(@update_user_phone_form.phone,
                                @update_user_phone_form.sms_otp_delivery)
      else
        redirect_to profile_url
      end
    end
  end
end

module Users
  class PhonesController < ReauthnRequiredController
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
      params.require(:update_user_phone_form).permit(:phone)
    end

    def process_updates
      if @update_user_phone_form.phone_changed?
        analytics.track_event(Analytics::PHONE_CHANGE_REQUESTED)
        flash[:notice] = t('devise.registrations.phone_update_needs_confirmation')
        prompt_to_confirm_phone(phone: @update_user_phone_form.phone)
      else
        redirect_to profile_url
      end
    end
  end
end

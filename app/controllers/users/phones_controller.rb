module Users
  class PhonesController < ReauthnRequiredController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated

    def edit
      @user_phone_form = UserPhoneForm.new(current_user)
      @presenter = PhoneSetupPresenter.new(current_user.otp_delivery_preference)
    end

    def update
      @user_phone_form = UserPhoneForm.new(current_user)
      @presenter = PhoneSetupPresenter.new(current_user)
      if @user_phone_form.submit(user_params).success?
        process_updates
        bypass_sign_in current_user
      else
        render :edit
      end
    end

    private

    def user_params
      params.require(:user_phone_form).permit(:phone, :international_code, :otp_delivery_preference)
    end

    def process_updates
      if @user_phone_form.phone_changed?
        analytics.track_event(Analytics::PHONE_CHANGE_REQUESTED)
        flash[:notice] = t('devise.registrations.phone_update_needs_confirmation')
        prompt_to_confirm_phone(phone: @user_phone_form.phone)
      else
        redirect_to account_url
      end
    end
  end
end

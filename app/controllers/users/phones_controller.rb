module Users
  class PhonesController < ReauthnRequiredController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated

    def edit
      @user_phone_form = UserPhoneForm.new(current_user, phone_configuration)
      @presenter = PhoneSetupPresenter.new(delivery_preference)
    end

    def update
      @user_phone_form = UserPhoneForm.new(current_user, phone_configuration)
      @presenter = PhoneSetupPresenter.new(delivery_preference)
      if @user_phone_form.submit(user_params).success?
        process_updates
        bypass_sign_in current_user
      else
        render :edit
      end
    end

    def delete
      analytics.track_event(Analytics::PHONE_DELETION_REQUESTED)
      result = TwoFactorAuthentication::PhoneDeletionForm.new(
        current_user, phone_configuration
      ).submit
      if result.success?
        flash[:success] = t('two_factor_authentication.phone.delete.success')
      else
        flash[:error] = t('two_factor_authentication.phone.delete.failure')
      end

      redirect_to account_url
    end

    private

    # we only allow editing of the first configuration since we'll eventually be
    # doing away with this controller. Once we move to multiple phones, we'll allow
    # adding and deleting, but not editing.
    def phone_configuration
      MfaContext.new(current_user).phone_configurations.first
    end

    def user_params
      params.require(:user_phone_form).permit(:phone, :international_code, :otp_delivery_preference)
    end

    def delivery_preference
      phone_configuration&.delivery_preference || current_user.otp_delivery_preference
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

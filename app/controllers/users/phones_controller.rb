module Users
  class PhonesController < ReauthnRequiredController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated

    def add
      user_session[:phone_id] = nil
      @user_phone_form = UserPhoneForm.new(current_user, nil)
    end

    def create
      @user_phone_form = UserPhoneForm.new(current_user, nil)
      if @user_phone_form.submit(user_params).success?
        confirm_phone
        bypass_sign_in current_user
      else
        render :add
      end
    end

    def edit
      set_phone_id
      # memoized for view
      user_phone_form
    end

    def update
      if user_phone_form.submit(user_params).success? && !already_has_phone?
        process_updates
        bypass_sign_in current_user
      else
        render_edit
      end
    end

    def delete
      result = TwoFactorAuthentication::PhoneDeletionForm.new(
        current_user, phone_configuration
      ).submit
      analytics.track_event(Analytics::PHONE_DELETION_REQUESTED, result.to_h)
      if result.success?
        handle_successful_delete
      else
        flash[:error] = t('two_factor_authentication.phone.delete.failure')
      end

      redirect_to account_url
    end

    private

    def user_phone_form
      @user_phone_form ||= UserPhoneForm.new(current_user, phone_configuration)
    end

    def render_edit
      flash.now[:error] = t('errors.messages.phone_duplicate') if already_has_phone?
      render :edit
    end

    # we only allow editing of the first configuration since we'll eventually be
    # doing away with this controller. Once we move to multiple phones, we'll allow
    # adding and deleting, but not editing.
    def phone_configuration
      MfaContext.new(current_user).phone_configuration(user_session[:phone_id])
    end

    def user_params
      params.require(:user_phone_form).permit(:phone, :international_code,
                                              :otp_delivery_preference,
                                              :otp_make_default_number)
    end

    def already_has_phone?
      @user_has_phone ||= @user_phone_form.already_has_phone?
    end

    def delivery_preference
      phone_configuration&.delivery_preference || current_user.otp_delivery_preference
    end

    def process_updates
      form = @user_phone_form
      if form.phone_config_changed?
        analytics.track_event(Analytics::PHONE_CHANGE_REQUESTED)

        OtpPreferenceUpdater.new(
          user: current_user,
          preference: form.otp_delivery_preference,
          default: form.otp_make_default_number,
          phone_id: user_session[:phone_id],
          ).call
      end
      redirect_to account_url
    end

    def confirm_phone
      flash[:notice] = t('devise.registrations.phone_update_needs_confirmation')
      prompt_to_confirm_phone(id: user_session[:phone_id], phone: @user_phone_form.phone,
                              selected_delivery_method: @user_phone_form.otp_delivery_preference,
                              selected_default_number: @user_phone_form.otp_make_default_number)
    end

    def handle_successful_delete
      flash[:success] = t('two_factor_authentication.phone.delete.success')
      create_user_event(:phone_removed)
    end

    def set_phone_id
      phone_id = params[:id]
      user_session[:phone_id] = phone_id if phone_id.present?
    end
  end
end

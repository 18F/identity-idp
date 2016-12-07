module Users
  class EditPasswordController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def edit
      @update_user_password_form = UpdateUserPasswordForm.new(current_user)
    end

    def update
      @update_user_password_form = UpdateUserPasswordForm.new(current_user)

      result = @update_user_password_form.submit(user_params)

      analytics.track_event(Analytics::PASSWORD_CHANGED, result)

      if result[:success]
        handle_success
      else
        render :edit
      end
    end

    private

    def user_params
      params.require(:update_user_password_form).permit(:password)
    end

    def handle_success
      re_encrypt_active_profile

      bypass_sign_in current_user

      redirect_to profile_url, notice: t('notices.password_changed')

      EmailNotifier.new(current_user).send_password_changed_email
    end

    def re_encrypt_active_profile
      active_profile = current_user.active_profile
      return unless active_profile.present?
      user_access_key = current_user.unlock_user_access_key(user_params[:password])
      flash[:recovery_code] = active_profile.encrypt_pii(user_access_key, current_pii)
      active_profile.save!
    end

    def current_pii
      cacher = Pii::Cacher.new(current_user, user_session)
      cacher.fetch
    end
  end
end

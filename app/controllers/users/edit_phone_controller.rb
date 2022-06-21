module Users
  class EditPhoneController < ReauthnRequiredController
    include RememberDeviceConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_user_can_edit_phone
    before_action :confirm_user_can_remove_phone, only: %i[destroy]

    def edit
      analytics.phone_change_viewed
      @edit_phone_form = EditPhoneForm.new(current_user, phone_configuration)
    end

    def update
      @edit_phone_form = EditPhoneForm.new(current_user, phone_configuration)
      result = @edit_phone_form.submit(edit_phone_params)
      analytics.phone_change_submitted(**result.to_h)
      if result.success?
        redirect_to account_url
      else
        render :edit
      end
    end

    def destroy
      track_deletion_analytics_event
      phone_configuration.destroy!
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
      revoke_remember_device(current_user)
      flash[:success] = t('two_factor_authentication.phone.delete.success')
      redirect_to account_url
    end

    private

    def confirm_user_can_edit_phone
      render_not_found if phone_configuration.nil?
      false
    end

    def confirm_user_can_remove_phone
      return if MfaPolicy.new(current_user).multiple_factors_enabled?
      flash[:error] = t('two_factor_authentication.phone.delete.failure')
      redirect_to account_url
      false
    end

    def track_deletion_analytics_event
      analytics.phone_deletion(
        success: true,
        phone_configuration_id: phone_configuration.id,
      )
      create_user_event(:phone_removed)
    end

    def phone_configuration
      @phone_configuration ||= current_user.phone_configurations.find_by(id: params[:id])
    end

    def edit_phone_params
      params.require(:edit_phone_form).permit(
        :delivery_preference,
        :make_default_number,
      )
    end
  end
end

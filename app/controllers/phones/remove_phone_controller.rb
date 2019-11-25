module Phones
  class RemovePhoneController < ReauthnRequiredController
    include RememberDeviceConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_user_can_remove_phone, only: %i[destroy]

    def destroy
      track_deletion_analytics_event
      phone_configuration.destroy!
      revoke_remember_device(current_user)
      flash[:success] = t('two_factor_authentication.phone.delete.success')
      redirect_to account_url
    end

    private

    def confirm_user_can_remove_phone
      return render_not_found if phone_configuration.nil?
      return if MfaPolicy.new(current_user).more_than_two_factors_enabled?
      flash[:error] = t('two_factor_authentication.phone.delete.failure')
      redirect_to account_url
      false
    end

    def track_deletion_analytics_event
      analytics.track_event(
        Analytics::PHONE_DELETION,
        success: true,
        phone_configuration_id: phone_configuration.id,
      )
      create_user_event(:phone_removed)
    end

    def phone_configuration
      @phone_configuration ||= current_user.phone_configurations.find_by(id: params[:id])
    end
  end
end

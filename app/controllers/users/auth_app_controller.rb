module Users
  class AuthAppController < ApplicationController
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated_2fa
    before_action :set_form
    before_action :validate_configuration_exists

    def edit; end

    def update
      binding.pry
      result = form.submit(name: params.dig(:form, :name))

      analytics.auth_app_update_name_submitted(**result.to_h)

      if result.success?
        flash[:success] = t('two_factor_authentication.auth_app.renamed')
        redirect_to account_path
      else
        flash.now[:error] = result.first_error_message
        render :edit
      end
    end

    def destroy
      result = form.submit

      analytics.auth_app_delete_submitted(**result.to_h)

      if result.success?
        flash[:success] = t('two_factor_authentication.webauthn_platform.deleted')
        create_user_event(:webauthn_key_removed)
        revoke_remember_device(current_user)
        event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
        PushNotification::HttpPush.deliver(event)
        redirect_to account_path
      else
        flash[:error] = result.first_error_message
        redirect_to edit_auth_app_path(id: params[:id])
      end
    end

    private

    def form
      @form ||= form_class.new(user: current_user, configuration_id: params[:id])
    end

    alias_method :set_form, :form

    def form_class
      case action_name
      when 'edit', 'update'
        TwoFactorAuthentication::AuthAppUpdateForm
      when 'destroy'
        TwoFactorAuthentication::AuthAppDeleteForm
      end
    end

    def validate_configuration_exists
      render_not_found if form.configuration.blank?
    end
  end
end

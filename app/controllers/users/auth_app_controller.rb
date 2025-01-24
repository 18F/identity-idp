# frozen_string_literal: true

module Users
  class AuthAppController < ApplicationController
    include ReauthenticationRequiredConcern
    include MfaDeletionConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated_2fa
    before_action :set_form
    before_action :validate_configuration_exists

    def edit; end

    def update
      result = form.submit(name: params.dig(:form, :name))

      analytics.auth_app_update_name_submitted(**result)

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

      analytics.auth_app_delete_submitted(**result)

      if result.success?
        flash[:success] = t('two_factor_authentication.auth_app.deleted')
        handle_successful_mfa_deletion(event_type: :authenticator_disabled)
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

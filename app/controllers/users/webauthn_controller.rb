# frozen_string_literal: true

module Users
  class WebauthnController < ApplicationController
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated_2fa
    before_action :set_form
    before_action :validate_configuration_exists
    before_action :set_presenter

    def edit; end

    def update
      result = form.submit(name: params.dig(:form, :name))

      analytics.webauthn_update_name_submitted(**result)

      if result.success?
        flash[:success] = presenter.rename_success_alert_text
        redirect_to account_path
      else
        flash.now[:error] = result.first_error_message
        render :edit
      end
    end

    def destroy
      result = form.submit

      analytics.webauthn_delete_submitted(**result)

      if result.success?
        flash[:success] = presenter.delete_success_alert_text
        create_user_event(:webauthn_key_removed)
        revoke_remember_device(current_user)
        event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
        PushNotification::HttpPush.deliver(event)
        redirect_to account_path
      else
        flash[:error] = result.first_error_message
        redirect_to edit_webauthn_path(id: params[:id])
      end
    end

    private

    def form
      @form ||= form_class.new(user: current_user, configuration_id: params[:id])
    end

    alias_method :set_form, :form

    delegate :configuration, to: :form

    def presenter
      @presenter ||= TwoFactorAuthentication::WebauthnEditPresenter.new(configuration:)
    end

    alias_method :set_presenter, :presenter

    def form_class
      case action_name
      when 'edit', 'update'
        TwoFactorAuthentication::WebauthnUpdateForm
      when 'destroy'
        TwoFactorAuthentication::WebauthnDeleteForm
      end
    end

    def validate_configuration_exists
      render_not_found if configuration.blank?
    end
  end
end

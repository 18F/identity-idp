# frozen_string_literal: true

module Users
  class StsConsentController < ApplicationController
    include SecureHeadersConcern

    before_action :ensure_sp_in_session_with_request_url, only: [:new, :create, :cancel]
    before_action :confirm_two_factor_authenticated
    before_action :confirm_token_exchange_enabled
    before_action :apply_secure_headers_override, only: [:new]

    def new
      analytics.sts_consent_visited
      @sts_consent_form = build_form
    end

    def create
      @sts_consent_form = build_form

      result = @sts_consent_form.submit(permitted_params)

      analytics.sts_consent_submitted(**result)

      if result.success?
        redirect_to sp_session_request_url_with_updated_params, allow_other_host: true
      else
        render :new
      end
    end

    def cancel
      redirect_url = sp_return_url_resolver.return_to_sp_url

      analytics.sts_consent_cancelled(redirect_url:)

      redirect_to redirect_url, allow_other_host: true
    end

    private

    def build_form
      StsConsentForm.new(user: current_user, target_app:, actor_app:)
    end

    def target_app
      sp_session[:sts_target_app]
    end

    def sp_return_url_resolver
      SpReturnUrlResolver.new(service_provider: current_sp)
    end

    def actor_app
      sp_session[:sts_actor_app]
    end

    def permitted_params
      params.require(:sts_consent_form).permit(:consent_given)
    end

    def confirm_token_exchange_enabled
      return if IdentityConfig.store.token_exchange_enabled

      redirect_to account_url
    end

    def ensure_sp_in_session_with_request_url
      return if sp_session&.dig(:request_url) && target_app.present? && actor_app.present?

      redirect_to account_url
    end
  end
end

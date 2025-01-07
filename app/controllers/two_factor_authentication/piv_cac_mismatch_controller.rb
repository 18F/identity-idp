# frozen_string_literal: true

module TwoFactorAuthentication
  class PivCacMismatchController < ApplicationController
    include TwoFactorAuthenticatable

    def show
      analytics.piv_cac_mismatch_visited(
        piv_cac_required: piv_cac_required?,
        has_other_authentication_methods: has_other_authentication_methods?,
      )

      @piv_cac_required = piv_cac_required?
      @has_other_authentication_methods = has_other_authentication_methods?
    end

    def create
      analytics.piv_cac_mismatch_submitted(add_piv_cac_after_2fa: add_piv_cac_after_2fa?)
      user_session[:add_piv_cac_after_2fa] = add_piv_cac_after_2fa?
      redirect_to login_two_factor_options_url
    end

    private

    def add_piv_cac_after_2fa?
      params[:add_piv_cac_after_2fa] == 'true'
    end

    def piv_cac_required?
      service_provider_mfa_policy.piv_cac_required?
    end

    def has_other_authentication_methods?
      return @has_other_authentication_methods if defined?(@has_other_authentication_methods)
      @has_other_authentication_methods = mfa_context.two_factor_configurations.any? do |config|
        config.mfa_enabled? && !config.is_a?(PivCacConfiguration)
      end
    end

    def mfa_context
      @mfa_context ||= MfaContext.new(current_user)
    end
  end
end

# frozen_string_literal: true

module SiteKeys
  # After a password reset, opens the site key with the recovery code so the next password entry
  # rewraps it, or lets the person start over with a new key.
  class RecoveriesController < ApplicationController
    include ReauthenticationRequiredConcern
    include SiteKeyConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated_2fa, only: [:confirm_destroy, :destroy]
    before_action :redirect_unless_recoverable

    def new
      analytics.site_key_recovery_visited
      @recovery_form = SiteKeys::RecoveryForm.new(vault: site_key_vault, code: '')

      if rate_limiter.limited?
        render_rate_limited
      else
        render :new
      end
    end

    def create
      rate_limiter.increment!
      return render_rate_limited if rate_limiter.limited?

      @recovery_form = SiteKeys::RecoveryForm.new(vault: site_key_vault, code: code_param)
      result = @recovery_form.submit
      analytics.site_key_recovery_submitted(
        **result,
        pii_like_keypaths: [[:errors, :code], [:error_details, :code]],
      )

      if result.success?
        rate_limiter.reset!
        redirect_to capture_password_url
      else
        render :new
      end
    end

    def confirm_destroy; end

    def destroy
      analytics.site_key_recovery_abandoned
      current_user.site_key.destroy!
      current_user.reload_site_key
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def redirect_unless_recoverable
      redirect_to after_sign_in_path_for(current_user) unless site_key_vault.recoverable?
    end

    def code_param
      params.require(:site_keys_recovery_form).permit(:code)[:code]
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(user: current_user, rate_limit_type: :site_key_recovery)
    end

    def render_rate_limited
      analytics.rate_limit_reached(limiter_type: :site_key_recovery)
      @expires_at = rate_limiter.expires_at
      render :rate_limited
    end
  end
end

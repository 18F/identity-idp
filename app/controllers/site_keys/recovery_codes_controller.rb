# frozen_string_literal: true

module SiteKeys
  # Shows a newly minted site key recovery code and lets users generate a new one.
  class RecoveryCodesController < ApplicationController
    include ReauthenticationRequiredConcern
    include SecureHeadersConcern
    include SiteKeyConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated_2fa, only: [:new, :create]
    before_action :redirect_if_recoverable, only: [:new, :create]
    before_action :apply_secure_headers_override, only: :show

    def show
      site_key_vault.show_unacknowledged_recovery_code
      code = site_key_vault.pending_recovery_code if site_key_vault.unlocked?
      analytics.site_key_recovery_code_viewed(present: code.present?)
      return redirect_to after_sign_in_path_for(current_user) if code.blank?

      @code = code
      @recovery_code_generated_at = current_user.site_key_root.recovery_code_generated_at
    end

    def update
      return redirect_to site_key_recovery_code_url unless acknowledgment_param?

      acknowledged = site_key_vault.acknowledge_recovery_code
      analytics.site_key_recovery_code_acknowledged(matched: acknowledged)
      redirect_to after_sign_in_path_for(current_user)
    end

    def new
      analytics.site_key_recovery_code_new_visited
    end

    def create
      if site_key_vault.unlocked?
        site_key_vault.regenerate_recovery_code
        analytics.site_key_recovery_code_regenerated
        redirect_to site_key_recovery_code_url
      else
        user_session[:stored_location] = new_site_key_recovery_code_url
        redirect_to capture_password_url
      end
    end

    private

    def redirect_if_recoverable
      redirect_to site_key_recovery_url if site_key_vault.recoverable?
    end

    def acknowledgment_param?
      params[:acknowledgment] == '1'
    end
  end
end

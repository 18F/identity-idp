# frozen_string_literal: true

module Users
  class SecondMfaReminderController < ApplicationController
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override

    def new
      analytics.second_mfa_reminder_visit
    end

    def create
      analytics.second_mfa_reminder_dismissed(opted_to_add: opted_to_add?)
      current_user.update(second_mfa_reminder_dismissed_at: Time.zone.now)
      user_session[:second_mfa_reminder_conversion] = true if opted_to_add?
      redirect_to dismiss_redirect_path
    end

    private

    def opted_to_add?
      params[:add_method].present?
    end

    def dismiss_redirect_path
      if opted_to_add?
        authentication_methods_setup_path
      else
        after_sign_in_path_for(current_user)
      end
    end
  end
end

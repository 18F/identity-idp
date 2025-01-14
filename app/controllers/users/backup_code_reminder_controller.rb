# frozen_string_literal: true

module Users
  class BackupCodeReminderController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      flash.now[:success] = t('notices.authenticated_successfully')
      analytics.backup_code_reminder_visited
    end

    def update
      user_session[:dismissed_backup_code_reminder] = true
      analytics.backup_code_reminder_submitted(has_codes: has_codes?)

      if has_codes?
        redirect_to after_sign_in_path_for(current_user)
      else
        redirect_to backup_code_regenerate_path
      end
    end

    private

    def has_codes?
      params[:has_codes].present?
    end
  end
end

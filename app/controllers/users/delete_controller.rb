module Users
  class DeleteController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :confirm_current_password, only: [:delete]

    def show; end

    def delete
      send_push_notifications
      current_user.destroy!
      sign_out
      flash[:success] = t('devise.registrations.destroyed')
      redirect_to root_url
    end

    private

    def confirm_current_password
      return if valid_password?

      flash[:error] = t('idv.errors.incorrect_password')
      render :show
    end

    def valid_password?
      current_user.valid_password?(password)
    end

    def password
      params.fetch(:user, {})[:password].presence
    end

    def send_push_notifications
      return if Figaro.env.push_notifications_enabled != 'true'
      PushNotification::AccountDelete.new.call(current_user.id)
    end
  end
end

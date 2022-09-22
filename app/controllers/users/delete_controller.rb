module Users
  class DeleteController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :confirm_current_password, only: [:delete]

    def show
      analytics.account_delete_visited
    end

    def delete
      irs_attempts_api_tracker.logged_in_account_purged(success: true)
      send_push_notifications
      delete_user
      sign_out
      flash[:success] = t('devise.registrations.destroyed')
      analytics.account_delete_submitted(success: true)
      redirect_to root_url
    end

    private

    def delete_user
      ActiveRecord::Base.transaction do
        Db::DeletedUser::Create.call(current_user.id)
        current_user.destroy!
      end
    end

    def confirm_current_password
      return if valid_password?

      flash[:error] = t('idv.errors.incorrect_password')
      analytics.account_delete_submitted(success: false)
      irs_attempts_api_tracker.logged_in_account_purged(success: false)
      render :show
    end

    def valid_password?
      current_user.valid_password?(password)
    end

    def password
      params.fetch(:user, {})[:password].presence
    end

    def send_push_notifications
      event = PushNotification::AccountPurgedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
    end
  end
end

module Users
  class DeleteController < ApplicationController
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_current_password, only: [:delete]
    before_action :confirm_recently_authenticated_2fa

    def show
      analytics.account_delete_visited
    end

    def delete
      irs_attempts_api_tracker.logged_in_account_purged(success: true)
      send_push_notifications
      notify_user_via_email_of_deletion
      delete_user
      sign_out
      flash[:success] = t('devise.registrations.destroyed')
      analytics.account_delete_submitted(success: true)
      redirect_to root_url
    end

    private

    def delete_user
      ActiveRecord::Base.transaction do
        DeletedUser.create_from_user(current_user)
        current_user.destroy!
      end
    end

    def confirm_current_password
      return if valid_password?

      flash.now[:error] = t('idv.errors.incorrect_password')
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

    # rubocop:disable IdentityIdp/MailLaterLinter
    def notify_user_via_email_of_deletion
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: current_user, email_address: email_address).
          account_delete_submitted.deliver_now
      end
    end
    # rubocop:enable IdentityIdp/MailLaterLinter
  end
end

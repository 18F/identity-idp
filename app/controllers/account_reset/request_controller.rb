module AccountReset
  class RequestController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :check_account_reset_enabled
    before_action :confirm_two_factor_enabled
    before_action :confirm_user_not_verified

    def show; end

    def create
      analytics.track_event(Analytics::ACCOUNT_RESET, event: :request)
      create_request
      send_notifications
      reset_session_with_email
      redirect_to account_reset_confirm_request_url
    end

    private

    def check_account_reset_enabled
      redirect_to root_url unless FeatureManagement.account_reset_enabled?
    end

    def confirm_user_not_verified
      # IAL1 users should not be able to reset account to comply with AAL2 reqs
      redirect_to account_url if decorated_user.identity_verified?
    end

    def reset_session_with_email
      email = current_user.email
      sign_out
      flash[:email] = email
    end

    def send_notifications
      phone = current_user.phone
      if phone
        SmsAccountResetNotifierJob.perform_now(
          phone: phone,
          cancel_token: current_user.account_reset_request.request_token
        )
      end
      UserMailer.account_reset_request(current_user).deliver_later
    end

    def create_request
      AccountResetService.new(current_user).create_request
    end

    def confirm_two_factor_enabled
      return if current_user.two_factor_enabled?

      redirect_to phone_setup_url
    end
  end
end

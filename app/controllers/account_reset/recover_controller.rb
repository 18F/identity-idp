module AccountReset
  class RecoverController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_two_factor_enabled
    before_action :confirm_user_verified

    def show
      analytics.track_event(Analytics::IAL2_RECOVERY_REQUEST_VISITED)
    end

    def create
      analytics.track_event(Analytics::IAL2_RECOVERY_REQUEST, analytics_attributes)
      Recover::CreateRecoverRequest.call(current_user.id)
      send_notifications
      redirect_to account_reset_recover_email_sent_url
    end

    private

    def send_notifications
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.confirm_email_and_reverify(email_address,
                                              current_user.account_recovery_request).deliver_later
      end
    end

    def confirm_two_factor_enabled
      return if MfaPolicy.new(current_user).two_factor_enabled?

      redirect_to two_factor_options_url
    end

    def confirm_user_verified
      redirect_to account_url unless decorated_user.identity_verified?
    end

    def analytics_attributes
      {
        event: 'request',
        sms_phone: TwoFactorAuthentication::PhonePolicy.new(current_user).configured?,
        totp: TwoFactorAuthentication::AuthAppPolicy.new(current_user).configured?,
        piv_cac: TwoFactorAuthentication::PivCacPolicy.new(current_user).configured?,
        email_addresses: current_user.email_addresses.count,
      }
    end
  end
end

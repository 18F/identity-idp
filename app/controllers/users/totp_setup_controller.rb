module Users
  class TotpSetupController < ApplicationController
    before_action :confirm_two_factor_authenticated
    layout 'card_wide'

    def start
    end

    def new
      user_session[:new_totp_secret] = current_user.generate_totp_secret if new_totp_secret.nil?

      @qrcode = decorated_user.qrcode(new_totp_secret)
    end

    def confirm
      if valid_code?
        current_user.save!
        process_valid_code
      else
        process_invalid_code
      end
    end

    def disable
      if current_user.otp_secret_key.present?
        current_user.update(otp_secret_key: nil)
        flash[:success] = t('notices.totp_disabled')
      end
      redirect_to profile_path
    end

    private

    def valid_code?
      return false if new_totp_secret.nil?
      current_user.confirm_totp_secret(new_totp_secret, params[:code].strip)
    end

    def process_valid_code
      flash[:success] = t('notices.totp_configured')
      redirect_to profile_path
      user_session.delete(:new_totp_secret)
    end

    def process_invalid_code
      flash[:error] = t('errors.invalid_totp')
      redirect_to authenticator_setup_path
    end

    def new_totp_secret
      user_session[:new_totp_secret]
    end
  end
end

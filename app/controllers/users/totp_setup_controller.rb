module Users
  class TotpSetupController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def new
      if user_session[:new_totp_secret].nil?
        user_session[:new_totp_secret] = current_user.generate_totp_secret
      end
      @qrcode = UserDecorator.new(current_user).qrcode(user_session[:new_totp_secret])
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
      end
      flash[:success] = t('notices.totp_disabled')
      redirect_to edit_user_registration_path
    end

    private

    def valid_code?
      return false if user_session[:new_totp_secret].nil?
      current_user.confirm_totp_secret(user_session[:new_totp_secret], params[:code].strip)
    end

    def process_valid_code
      flash[:success] = t('notices.totp_configured')
      redirect_to edit_user_registration_path
      user_session.delete(:new_totp_secret)
    end

    def process_invalid_code
      flash[:error] = t('errors.invalid_totp')
      redirect_to users_totp_path
    end
  end
end

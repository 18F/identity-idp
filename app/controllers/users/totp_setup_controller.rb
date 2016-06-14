module Users
  class TotpSetupController < ApplicationController

    #before_action :confirm_two_factor_authenticated
    before_action :authenticate_user!

    # GET /users/totp
    def index
      puts 'index'
      if session[:otp_secret_key].nil?
        session[:otp_secret_key] = current_user.generate_totp_secret
      end
      puts "sending qr code to user: #{session[:otp_secret_key]}"
      @qrcode = UserDecorator.new(current_user).qrcode(session[:otp_secret_key])
    end

    # PATCH /users/totp
    def confirm
      if current_user.confirm_totp_secret(session[:otp_secret_key], params[:code].strip)
        flash[:success] = 'Authenticator successfully configured'
        current_user.save
        redirect_to(root_url)
      else
        flash[:error] = t('upaya.errors.invalid_totp')
        redirect_to users_totp_path
      end
    end
  end
end

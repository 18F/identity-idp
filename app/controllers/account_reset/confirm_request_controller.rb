module AccountReset
  class ConfirmRequestController < ApplicationController
    def show
      email = flash[:email]
      if email.blank?
        redirect_to root_url
      else
        render :show, locals: {
          email: email, sms_phone: SmsLoginOptionPolicy.new(current_user).configured?
        }
        sign_out
      end
    end
  end
end

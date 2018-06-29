module AccountReset
  class ConfirmDeleteAccountController < ApplicationController
    def show
      email = flash[:email]
      if email.blank?
        redirect_to root_url
      else
        render :show, locals: { email: email }
      end
    end
  end
end

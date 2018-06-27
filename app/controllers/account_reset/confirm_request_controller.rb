module AccountReset
  class ConfirmRequestController < ApplicationController
    def show
      if session[:email].blank?
        redirect_to root_url
      else
        email = session.delete(:email)
        render :show, locals: { email: email }
      end
    end
  end
end

module AccountReset
  class ConfirmRequestController < ApplicationController
    def show
      if flash[:email].blank?
        redirect_to root_url
      else
        render :show, locals: { email: flash[:email] }
      end
    end
  end
end

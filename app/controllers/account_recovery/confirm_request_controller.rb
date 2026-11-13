# frozen_string_literal: true

module AccountRecovery
  class ConfirmRequestController < ApplicationController
    def show
      email = flash[:email]
      return redirect_to root_url if email.blank?

      sign_out
      render :show, locals: { email: email }
    end
  end
end

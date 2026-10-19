# frozen_string_literal: true

module AccountRecovery
  class ConfirmRequestController < ApplicationController
    include AccountRecoveryConcern

    def show
      email = flash[:email]
      return redirect_to root_url if email.blank?

      render :show, locals: { email: email }
      sign_out
    end
  end
end

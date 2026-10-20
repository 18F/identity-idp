# frozen_string_literal: true

module DestructiveAccountReset
  class ConfirmRequestController < ApplicationController
    include DestructiveAccountResetConcern
    def show
      email = flash[:email]
      if email.blank?
        redirect_to root_url
      else
        render :show, locals: {
          email: email,
          sms_phone: TwoFactorAuthentication::PhonePolicy.new(current_user).configured?,
          waiting_period: account_reset_deletion_period_interval(current_user),
        }
        sign_out
      end
    end
  end
end

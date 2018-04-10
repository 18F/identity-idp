module TwoFactorAuthentication
  class ResetDeviceController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_two_factor_enabled

    def show
      @presenter = presenter_for_two_factor_authentication_method
    end

    def create
      return unless Figaro.env.reset_device_enabled == 'true'
      create_request
      UserMailer.reset_device(current_user).deliver_later
      sign_out
      flash[:success] = t('devise.two_factor_authentication.reset_device.success_message')
      redirect_to root_url
    end

    private

    def create_request
      analytics.track_event(Analytics::RESET_DEVICE_REQUESTED)
      ResetDevice.new(current_user).create_request
    end

    def confirm_two_factor_enabled
      return if current_user.two_factor_enabled?

      redirect_to phone_setup_url
    end
  end
end

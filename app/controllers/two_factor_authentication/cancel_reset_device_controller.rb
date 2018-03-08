module TwoFactorAuthentication
  class CancelResetDeviceController < ApplicationController
    def cancel
      is_fraud = params[:only].blank?
      is_token_valid = if is_fraud
                         cancel_and_report_fraud
                       else
                         cancel_request
                       end
      log_events(is_fraud, is_token_valid)
      render_success
    end

    private

    def log_events(is_fraud, is_token_valid)
      return if params[:token].blank?
      analytics.track_event(Analytics::RESET_DEVICE_CANCELLED,
                            fraud: is_fraud,
                            token_valid: is_token_valid)
    end

    def render_success
      sign_out
      flash[:success] = t('devise.two_factor_authentication.reset_device.successful_cancel')
      redirect_to root_url
    end

    def cancel_request
      ResetDevice.cancel_request(params[:token])
    end

    def cancel_and_report_fraud
      ResetDevice.report_fraud(params[:token])
    end
  end
end

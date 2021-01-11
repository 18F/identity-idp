class FrontendLogController < ApplicationController

  respond_to :json

  def create
    if user_fully_authenticated?
      log_level, payload = log_params
      case log_level
      when 'error'
        Rails.logger.error { payload.to_json }
      when 'warn'
        Rails.logger.warn { payload.to_json }
      when 'debug'
        Rails.logger.debug { payload.to_json }
      else
        Rails.logger.info { payload.to_json }
      end

      render json: { success: true }, status: :ok
    else
      render json: { success: false }, status: :unauthorized
    end

  rescue ActionController::ParameterMissing => pm
    render json: { success: false, error_message: pm.to_s }, status: :bad_request
  end

  private

  def log_params
    params.require([:log_level, :payload])
  end
end

class FrontendLogController < ApplicationController

  respond_to :json

  def create
    if user_fully_authenticated?
      event, payload = log_params
      analytics.track_event(event, payload)

      render json: { success: true }, status: :ok
    else
      render json: { success: false }, status: :unauthorized
    end

  rescue ActionController::ParameterMissing => pm
    render json: { success: false, error_message: pm.to_s }, status: :bad_request
  end

  private

  def log_params
    params.require([:event, :payload])
  end
end

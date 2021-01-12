class FrontendLogController < ApplicationController

  respond_to :json

  before_action :check_user_authenticated
  before_action :validate_parameter_types

  def create
    analytics.track_event(log_params[:event], log_params[:payload].to_h)

    render json: { success: true }, status: :ok
  end

  private

  def log_params
    params.permit(:event, payload: {})
  end

  def check_user_authenticated
    return if user_fully_authenticated?

    render json: { success: false }, status: :unauthorized
  end

  def validate_parameter_types
    return if valid_event? && valid_payload?

    render json: { success: false, error_message: 'incorrect parameter types' },
           status: :bad_request
  end

  def valid_event?
    log_params[:event].is_a?(String) && log_params[:event].present?
  end

  def valid_payload?
    payload = log_params[:payload].to_h
    payload.is_a?(Hash) && payload.present?
  end
end

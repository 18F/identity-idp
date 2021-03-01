class FrontendLogController < ApplicationController
  include EffectiveUser

  respond_to :json

  skip_before_action :verify_authenticity_token
  before_action :check_user_authenticated
  before_action :validate_parameter_types

  def create
    event = "Frontend: #{log_params[:event]}"
    analytics.track_event(event, log_params[:payload].to_h.merge(user_id: effective_user_id))

    render json: { success: true }, status: :ok
  end

  private

  def log_params
    params.permit(:event, payload: {})
  end

  def check_user_authenticated
    return if effective_user_id

    render json: { success: false }, status: :unauthorized
  end

  def validate_parameter_types
    return if valid_event? && valid_payload?

    render json: { success: false, error_message: 'invalid parameters' },
           status: :bad_request
  end

  def valid_event?
    log_params[:event].is_a?(String) &&
      log_params[:event].present?
  end

  def valid_payload?
    payload = log_params[:payload].to_h
    payload.is_a?(Hash) && payload.present?
  end
end

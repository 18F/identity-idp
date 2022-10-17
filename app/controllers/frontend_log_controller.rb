class FrontendLogController < ApplicationController
  respond_to :json

  skip_before_action :verify_authenticity_token
  before_action :validate_parameter_types

  # rubocop:disable Layout/LineLength
  EVENT_MAP = {
    'IdV: verify in person troubleshooting option clicked' => :idv_verify_in_person_troubleshooting_option_clicked,
    'IdV: location visited' => :idv_in_person_location_visited,
    'IdV: location submitted' => :idv_in_person_location_submitted,
    'IdV: prepare visited' => :idv_in_person_prepare_visited,
    'IdV: prepare submitted' => :idv_in_person_prepare_submitted,
    'IdV: switch_back visited' => :idv_in_person_switch_back_visited,
    'IdV: switch_back submitted' => :idv_in_person_switch_back_submitted,
    'IdV: download personal key' => :idv_personal_key_downloaded,
    'IdV: Native camera forced after failed attempts' => :idv_native_camera_forced,
    'Multi-Factor Authentication: download backup code' => :multi_factor_auth_backup_code_download,
    'Show Password button clicked' => :show_password_button_clicked,
    'IdV: personal key acknowledgment toggled' => :personal_key_acknowledgment_toggled,
  }.transform_values { |method| AnalyticsEvents.instance_method(method) }.freeze
  # rubocop:enable Layout/LineLength

  def create
    frontend_logger.track_event(log_params[:event], log_params[:payload].to_h)

    render json: { success: true }, status: :ok
  end

  private

  def frontend_logger
    FrontendLogger.new(analytics: analytics, event_map: EVENT_MAP)
  end

  def log_params
    params.permit(:event, payload: {})
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
    !log_params[:payload].nil?
  end
end

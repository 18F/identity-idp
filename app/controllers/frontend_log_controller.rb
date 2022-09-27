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
    'IdV: forgot password visited' => :idv_forgot_password,
    'IdV: password confirm visited' => :idv_review_info_visited,
    'IdV: password confirm submitted' => proc do |analytics|
      analytics.idv_review_complete(success: true)
      analytics.idv_final(success: true)
    end,
    'IdV: personal key visited' => :idv_personal_key_visited,
    'IdV: personal key submitted' => :idv_personal_key_submitted,
    'IdV: personal key confirm visited' => :idv_personal_key_confirm_visited,
    'IdV: personal key confirm submitted' => :idv_personal_key_confirm_submitted,
    'IdV: download personal key' => :idv_personal_key_downloaded,
    'IdV: Native camera forced after failed attempts' => :idv_native_camera_forced,
    'Multi-Factor Authentication: download backup code' => :multi_factor_auth_backup_code_download,
    'Show Password button clicked' => :show_password_button_clicked,
  }.transform_values do |method|
    method.is_a?(Proc) ? method : AnalyticsEvents.instance_method(method)
  end.freeze
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

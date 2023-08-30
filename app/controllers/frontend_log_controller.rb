class FrontendLogController < ApplicationController
  respond_to :json

  skip_before_action :verify_authenticity_token
  before_action :validate_parameter_types

  # Don't write session data back to Redis for these requests.
  # In rare circumstances, these writes can clobber other, more important writes.
  before_action :skip_session_commit

  # Please try to keep this list alphabetical as well!
  # rubocop:disable Layout/LineLength
  EVENT_MAP = {
    'Frontend Error' => [FrontendErrorLogger, :track_error],
    'IdV: consent checkbox toggled' => [Analytics, :idv_consent_checkbox_toggled],
    'IdV: download personal key' => [Analytics, :idv_personal_key_downloaded],
    'IdV: location submitted' => [Analytics, :idv_in_person_location_submitted],
    'IdV: location visited' => [Analytics, :idv_in_person_location_visited],
    'IdV: Mobile device and camera check' => [Analytics, :idv_mobile_device_and_camera_check],
    'IdV: Native camera forced after failed attempts' => [Analytics, :idv_native_camera_forced],
    'IdV: personal key acknowledgment toggled' => [Analytics, :idv_personal_key_acknowledgment_toggled],
    'IdV: prepare submitted' => [Analytics, :idv_in_person_prepare_submitted],
    'IdV: prepare visited' => [Analytics, :idv_in_person_prepare_visited],
    'IdV: switch_back submitted' => [Analytics, :idv_in_person_switch_back_submitted],
    'IdV: switch_back visited' => [Analytics, :idv_in_person_switch_back_visited],
    'IdV: user clicked sp link on ready to verify page' => [Analytics, :idv_in_person_ready_to_verify_sp_link_clicked],
    'IdV: user clicked what to bring link on ready to verify page' => [Analytics, :idv_in_person_ready_to_verify_what_to_bring_link_clicked],
    'IdV: verify in person troubleshooting option clicked' => [Analytics, :idv_verify_in_person_troubleshooting_option_clicked],
    'Multi-Factor Authentication: download backup code' => [Analytics, :multi_factor_auth_backup_code_download],
    'Show Password button clicked' => [Analytics, :show_password_button_clicked],
    'Sign In: IdV requirements accordion clicked' => [Analytics, :sign_in_idv_requirements_accordion_clicked],
    'User prompted before navigation' => [Analytics, :user_prompted_before_navigation],
    'User prompted before navigation and still on page' => [Analytics, :user_prompted_before_navigation_and_still_on_page],
  }.freeze
  # rubocop:enable Layout/LineLength

  def create
    frontend_logger.track_event(log_params[:event], log_params[:payload].to_h)

    render json: { success: true }, status: :ok
  end

  private

  def frontend_logger
    FrontendLogger.new(analytics: analytics, error_logger: FrontendErrorLogger.new, event_map: EVENT_MAP)
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
    params[:payload].nil? || !log_params[:payload].nil?
  end
end

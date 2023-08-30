class FrontendLogController < ApplicationController
  class FrontendError < StandardError; end

  respond_to :json

  skip_before_action :verify_authenticity_token
  before_action :validate_parameter_types

  # Don't write session data back to Redis for these requests.
  # In rare circumstances, these writes can clobber other, more important writes.
  before_action :skip_session_commit

  # Please try to keep this list alphabetical as well!
  # rubocop:disable Layout/LineLength
  EVENT_MAP = {
    'Frontend Error' => proc { |_analytics, payload| NewRelic::Agent.notice_error(FrontendError.new, custom_params: payload) },
    'IdV: consent checkbox toggled' => :idv_consent_checkbox_toggled,
    'IdV: download personal key' => :idv_personal_key_downloaded,
    'IdV: location submitted' => :idv_in_person_location_submitted,
    'IdV: location visited' => :idv_in_person_location_visited,
    'IdV: Mobile device and camera check' => :idv_mobile_device_and_camera_check,
    'IdV: Native camera forced after failed attempts' => :idv_native_camera_forced,
    'IdV: personal key acknowledgment toggled' => :idv_personal_key_acknowledgment_toggled,
    'IdV: prepare submitted' => :idv_in_person_prepare_submitted,
    'IdV: prepare visited' => :idv_in_person_prepare_visited,
    'IdV: switch_back submitted' => :idv_in_person_switch_back_submitted,
    'IdV: switch_back visited' => :idv_in_person_switch_back_visited,
    'IdV: user clicked sp link on ready to verify page' => :idv_in_person_ready_to_verify_sp_link_clicked,
    'IdV: user clicked what to bring link on ready to verify page' => :idv_in_person_ready_to_verify_what_to_bring_link_clicked,
    'IdV: verify in person troubleshooting option clicked' => :idv_verify_in_person_troubleshooting_option_clicked,
    'Multi-Factor Authentication: download backup code' => :multi_factor_auth_backup_code_download,
    'Show Password button clicked' => :show_password_button_clicked,
    'Sign In: IdV requirements accordion clicked' => :sign_in_idv_requirements_accordion_clicked,
    'User prompted before navigation' => :user_prompted_before_navigation,
    'User prompted before navigation and still on page' => :user_prompted_before_navigation_and_still_on_page,
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
    params[:payload].nil? || !log_params[:payload].nil?
  end
end

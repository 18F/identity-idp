# frozen_string_literal: true

class FrontendLogController < ApplicationController
  include Idv::HybridMobile::HybridMobileConcern
  respond_to :json

  skip_before_action :verify_authenticity_token
  before_action :validate_parameter_types

  # Don't write session data back to Redis for these requests.
  # In rare circumstances, these writes can clobber other, more important writes.
  before_action :skip_session_commit

  # Please try to keep this list alphabetical as well!
  # rubocop:disable Layout/LineLength
  LEGACY_EVENT_MAP = {
    'Frontend Error' => FrontendErrorLogger.method(:track_error),
    'IdV: Acuant SDK loaded' => :idv_acuant_sdk_loaded,
    'IdV: back image added' => :idv_back_image_added,
    'IdV: back image clicked' => :idv_back_image_clicked,
    'IdV: barcode warning continue clicked' => :idv_barcode_warning_continue_clicked,
    'IdV: barcode warning retake photos clicked' => :idv_barcode_warning_retake_photos_clicked,
    'IdV: Capture troubleshooting dismissed' => :idv_capture_troubleshooting_dismissed,
    'IdV: consent checkbox toggled' => :idv_consent_checkbox_toggled,
    'IdV: download personal key' => :idv_personal_key_downloaded,
    'IdV: front image added' => :idv_front_image_added,
    'IdV: front image clicked' => :idv_front_image_clicked,
    'IdV: Image capture failed' => :idv_image_capture_failed,
    'IdV: Link sent capture doc polling complete' => :idv_link_sent_capture_doc_polling_complete,
    'IdV: Link sent capture doc polling started' => :idv_link_sent_capture_doc_polling_started,
    'IdV: location submitted' => :idv_in_person_location_submitted,
    'IdV: location visited' => :idv_in_person_location_visited,
    'IdV: Native camera forced after failed attempts' => :idv_native_camera_forced,
    'IdV: personal key acknowledgment toggled' => :idv_personal_key_acknowledgment_toggled,
    'IdV: prepare submitted' => :idv_in_person_prepare_submitted,
    'IdV: prepare visited' => :idv_in_person_prepare_visited,
    'IdV: switch_back submitted' => :idv_in_person_switch_back_submitted,
    'IdV: switch_back visited' => :idv_in_person_switch_back_visited,
    'IdV: user clicked sp link on ready to verify page' => :idv_in_person_ready_to_verify_sp_link_clicked,
    'IdV: user clicked what to bring link on ready to verify page' => :idv_in_person_ready_to_verify_what_to_bring_link_clicked,
    'IdV: verify in person troubleshooting option clicked' => :idv_verify_in_person_troubleshooting_option_clicked,
    'IdV: warning action triggered' => :idv_warning_action_triggered,
    'IdV: warning shown' => :idv_warning_shown,
    'Multi-Factor Authentication: download backup code' => :multi_factor_auth_backup_code_download,
  }.freeze
  # rubocop:enable Layout/LineLength

  ALLOWED_EVENTS = %i[
    idv_camera_info_error
    idv_camera_info_logged
    idv_sdk_error_before_init
    idv_sdk_selfie_image_capture_closed_without_photo
    idv_sdk_selfie_image_capture_failed
    idv_sdk_selfie_image_capture_initialized
    idv_sdk_selfie_image_capture_opened
    idv_sdk_selfie_image_re_taken
    idv_sdk_selfie_image_taken
    idv_selfie_image_added
    idv_selfie_image_clicked
    phone_input_country_changed
    sign_in_nav_button_clicked
    sign_up_nav_button_clicked
  ].freeze

  EVENT_MAP = ALLOWED_EVENTS.index_by(&:to_s).merge(LEGACY_EVENT_MAP).freeze

  def create
    success = frontend_logger.track_event(log_params[:event], log_params[:payload].to_h)

    if success
      render json: { success: }, status: :ok
    else
      render json: { success:, error_message: 'invalid event' }, status: :bad_request
    end
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

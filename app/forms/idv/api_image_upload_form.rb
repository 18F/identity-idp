module Idv
  class ApiImageUploadForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    IMAGE_KEYS = %i[
      front
      back
      selfie
    ].freeze

    validates_presence_of :front
    validates_presence_of :back
    validates_presence_of :document_capture_session
    validates_presence_of :selfie, if: :liveness_checking_enabled?

    validate :validate_images
    validate :throttle_if_rate_limited

    def initialize(params, liveness_checking_enabled:)
      @params = params
      @liveness_checking_enabled = liveness_checking_enabled
    end

    def submit
      FormResponse.new(
        success: valid?,
        errors: errors.messages,
        extra: {
          remaining_attempts: remaining_attempts,
        },
      )
    end

    def status
      return :ok if valid?
      return :too_many_requests if errors.key?(:limit)
      :bad_request
    end

    def remaining_attempts
      return if valid?
      Throttler::RemainingCount.call(document_capture_session.user_id, :idv_acuant)
    end

    def liveness_checking_enabled?
      @liveness_checking_enabled
    end

    def front
      params[:front]
    end

    def back
      params[:back]
    end

    def selfie
      params[:selfie]
    end

    def document_capture_session_uuid
      params[:document_capture_session_uuid]
    end

    def document_capture_session
      @document_capture_session ||= DocumentCaptureSession.find_by(
        uuid: document_capture_session_uuid,
      )
    end

    def self.human_attribute_name(attr, options = {})
      # i18n-tasks-use t('doc_auth.headings.document_capture_front')
      # i18n-tasks-use t('doc_auth.headings.document_capture_back')
      # i18n-tasks-use t('doc_auth.headings.document_capture_selfie')
      I18n.t("doc_auth.headings.document_capture_#{attr}", options)
    end

    private

    attr_reader :params

    def throttle_if_rate_limited
      return unless document_capture_session && throttled_else_increment
      errors.add(:limit, t('errors.doc_auth.acuant_throttle'))
    end

    def throttled_else_increment
      Throttler::IsThrottledElseIncrement.call(document_capture_session.user_id, :idv_acuant)
    end

    def validate_images
      IMAGE_KEYS.each do |image_key|
        validate_image(image_key) if params[image_key]
      end
    end

    def validate_image(image_key)
      file = params[image_key]

      return if file.respond_to?(:read)
      errors.add(image_key, t('doc_auth.errors.not_a_file'))
    end
  end
end

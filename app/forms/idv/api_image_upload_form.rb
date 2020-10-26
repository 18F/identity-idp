module Idv
  class ApiImageUploadForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    validates_presence_of :front
    validates_presence_of :back
    validates_presence_of :document_capture_session
    validates_presence_of :selfie, if: :liveness_checking_enabled?

    validate :validate_images
    validate :throttle_if_rate_limited

    def initialize(params, liveness_checking_enabled:)
      @params = params
      @liveness_checking_enabled = liveness_checking_enabled
      @readable = {}
    end

    def submit
      throttled_else_increment

      FormResponse.new(
        success: valid?,
        errors: errors.messages,
        extra: {
          remaining_attempts: remaining_attempts,
          user_id: document_capture_session&.user&.uuid,
        },
      )
    end

    def remaining_attempts
      Throttler::RemainingCount.call(document_capture_session.user_id, :idv_acuant)
    end

    def liveness_checking_enabled?
      @liveness_checking_enabled
    end

    def front
      as_readable(:front)
    end

    def back
      as_readable(:back)
    end

    def selfie
      as_readable(:selfie)
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
      return unless @throttled
      errors.add(:limit, t('errors.doc_auth.acuant_throttle'))
    end

    def throttled_else_increment
      @throttled = Throttler::IsThrottledElseIncrement.call(
        document_capture_session.user_id,
        :idv_acuant,
      )
    end

    def validate_images
      errors.add(:front, t('doc_auth.errors.not_a_file')) if front.is_a? URI::InvalidURIError
      errors.add(:back, t('doc_auth.errors.not_a_file')) if back.is_a? URI::InvalidURIError
      errors.add(:selfie, t('doc_auth.errors.not_a_file')) if selfie.is_a? URI::InvalidURIError
    end

    def as_readable(image_key)
      return @readable[image_key] if @readable.key?(image_key)

      value = params[image_key]
      @readable[image_key] = begin
        if value.respond_to?(:read)
          value
        elsif value.is_a? String
          DataUrlImage.new(value)
        end
      rescue URI::InvalidURIError => error
        error
      end
    end
  end
end

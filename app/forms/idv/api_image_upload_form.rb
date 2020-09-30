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

    validate :throttle_if_rate_limited

    def initialize(params, liveness_checking_enabled:)
      @params = params
      @liveness_checking_enabled = liveness_checking_enabled
    end

    def submit
      throttled_else_increment

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
      Throttler::RemainingCount.call(document_capture_session.user_id, :idv_acuant)
    end

    def liveness_checking_enabled?
      @liveness_checking_enabled
    end

    def front
      as_readable(params[:front])
    end

    def back
      as_readable(params[:back])
    end

    def selfie
      as_readable(params[:selfie])
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

    def as_readable(value)
      return value if value.respond_to?(:read)
      return DataUrlImage.new(value) if value.is_a? String
    end
  end
end

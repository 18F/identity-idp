module Idv
  class ApiDocumentVerificationStatusForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    validate :timeout_error
    validate :failed_result

    def initialize(async_state:, document_capture_session:)
      @async_state = async_state
      @document_capture_session = document_capture_session
    end

    def submit
      FormResponse.new(
        success: valid?,
        errors: errors,
        extra: {
          remaining_attempts: remaining_attempts,
        },
      )
    end

    def remaining_attempts
      return unless @document_capture_session
      RedisThrottle.new(
        user: @document_capture_session.user,
        throttle_type: :idv_doc_auth,
      ).remaining_count
    end

    def timeout_error
      return unless @async_state.missing?
      errors.add(
        :timeout, t('errors.doc_auth.document_verification_timeout'),
        type: :document_verification_timeout
      )
    end

    def failed_result
      return if !@async_state.done? || @async_state.result[:success]
      @async_state.result[:errors].each do |key, error|
        errors.add(key, error, type: error)
      end
    end
  end
end

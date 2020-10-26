module Idv
  class ApiDocumentVerificationStatusForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    validate :throttle_if_rate_limited
    validate :timeout_error
    validate :failed_result

    def initialize(async_state:, document_capture_session:)
      @async_state = async_state
      @document_capture_session = document_capture_session
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

    def remaining_attempts
      return unless @document_capture_session
      Throttler::RemainingCount.call(@document_capture_session.user_id, :idv_acuant)
    end

    def throttle_if_rate_limited
      return unless remaining_attempts.zero?
      errors.add(:limit, t('errors.doc_auth.acuant_throttle'))
    end

    def timeout_error
      return unless @async_state.status == :timeout
      errors.add(:timeout, t('errors.doc_auth.document_verification_timeout'))
    end

    def failed_result
      return unless @async_state.status == :done && !@async_state.result[:success]
      @async_state.result[:errors].each { |key, error| errors.add(key, error) }
    end
  end
end

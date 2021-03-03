module Idv
  module Steps
    class LinkSentStep < DocAuthBaseStep
      def call
        return render_document_capture_cancelled if document_capture_session&.cancelled_at
        return render_step_incomplete_error unless take_photo_with_phone_successful?

        # The doc capture flow will have fetched the results already. We need
        # to fetch them again here to add the PII to this session
        handle_document_verification_success(document_capture_session_result)
      end

      private

      def handle_document_verification_success(get_results_response)
        save_proofing_components
        extract_pii_from_doc(get_results_response)
        mark_steps_complete
      end

      def handle_document_verification_failure(get_results_response)
        mark_step_incomplete(:send_link)
        failure(get_results_response.first_error_message, get_results_response.to_h)
      end

      def render_document_capture_cancelled
        failure(I18n.t('errors.doc_auth.document_capture_cancelled'))
      end

      def render_step_incomplete_error
        failure(I18n.t('errors.doc_auth.phone_step_incomplete'))
      end

      def take_photo_with_phone_successful?
        document_capture_session_result.present?
      end

      def document_capture_session_result
        @document_capture_session_result ||= (
          document_capture_session&.load_result ||
          document_capture_session&.load_doc_auth_async_result
        )
      end

      def mark_steps_complete
        %i[send_link link_sent email_sent document_capture].each do |step|
          mark_step_complete(step)
        end
      end
    end
  end
end

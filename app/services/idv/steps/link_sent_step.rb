module Idv
  module Steps
    class LinkSentStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_id

      HYBRID_FLOW_STEPS = %i[upload send_link link_sent email_sent document_capture]

      def self.analytics_visited_event
        :idv_doc_auth_link_sent_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_link_sent_submitted
      end

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
        extract_pii_from_doc(get_results_response, store_in_session: true)
        mark_steps_complete
      end

      def render_document_capture_cancelled
        mark_steps_incomplete
        redirect_to idv_url
        failure(I18n.t('errors.doc_auth.document_capture_cancelled'))
      end

      def render_step_incomplete_error
        failure(I18n.t('errors.doc_auth.phone_step_incomplete'))
      end

      def take_photo_with_phone_successful?
        document_capture_session_result.present? && document_capture_session_result.success?
      end

      def document_capture_session_result
        @document_capture_session_result ||= begin
          document_capture_session&.load_result ||
            document_capture_session&.load_doc_auth_async_result
        end
      end

      def mark_steps_complete
        HYBRID_FLOW_STEPS.each { |step| mark_step_complete(step) }
      end

      def mark_steps_incomplete
        HYBRID_FLOW_STEPS.each { |step| mark_step_incomplete(step) }
      end
    end
  end
end

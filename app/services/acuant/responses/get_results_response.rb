module Acuant
  module Responses
    class GetResultsResponse < Acuant::Response
      GOOD_RESULT = 1
      FYI_RESULT = 2

      def initialize(http_response)
        @http_response = http_response
        super(
          success: successful_result?,
          errors: error_messages_from_alerts,
        )
      end

      def pii_from_doc
        return {} unless successful_result?

        ::Acuant::PiiFromDoc.new(parsed_response_body).call
      end

      # Explicitly override #to_h here because this method response object contains PII.
      # This method is used to determine what from this response gets written to events.log.
      # #to_h is defined on the super class and should not include any parts of the response that
      # contain PII. This method is here as a safegaurd in case that changes.
      def to_h
        {
          success: success?,
          erorrs: errors,
          exception: exception,
        }
      end

      private

      attr_reader :http_response

      def error_messages_from_alerts
        return [] if successful_result?

        raw_alerts.map do |raw_alert|
          # If a friendly message exists for this alert, we want to return that.
          # If a friendly message does not exist, FriendlyError::Message will return the raw alert
          # to us. In that case we respond with a general error.
          raw_alert_message = raw_alert['Disposition']
          friendly_message = FriendlyError::Message.call(raw_alert_message, 'doc_auth')
          next I18n.t('errors.doc_auth.general_error') if friendly_message == raw_alert_message
          friendly_message
        end
      end

      def parsed_response_body
        @parsed_response_body ||= JSON.parse(http_response.body)
      end

      def raw_alerts
        parsed_response_body['Alerts']
      end

      def successful_result?
        parsed_response_body['Result'] == GOOD_RESULT
      end
    end
  end
end

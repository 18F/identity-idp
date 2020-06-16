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

        Idv::Utils::PiiFromDoc.new(parsed_response_body).call(nil)
      end

      private

      attr_reader :http_response

      def error_messages_from_alerts
        return [] if successful_result?

        raw_alerts.map do |raw_alert|
          FriendlyError::Message.call(raw_alert['Disposition'], 'doc_auth')
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

module DocAuth
  module Acuant
    module Responses
      class FacialMatchResponse < DocAuth::Response
        attr_reader :http_response

        def initialize(http_response)
          @http_response = http_response
          super(
            success: successful_result?,
            errors: error_messages,
            extra: extra_attributes,
          )
        end

        private

        def error_messages
          return {} if successful_result?
          {
            selfie: I18n.t('errors.doc_auth.selfie'),
          }
        end

        def extra_attributes
          {
            match_score: match_score,
          }
        end

        def match_score
          parsed_response_body['Score']
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body)
        end

        def successful_result?
          parsed_response_body['IsMatch'] == true
        end
      end
    end
  end
end

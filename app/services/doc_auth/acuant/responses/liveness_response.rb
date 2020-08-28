module DocAuth
  module Acuant
    module Responses
      class LivenessResponse < DocAuth::Response
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

        def acuant_error
          {
            message: parsed_response_body['Error'],
            code: parsed_response_body['ErrorCode'],
          }
        end

        def error_messages
          return {} if successful_result?
          {
            selfie: I18n.t('errors.doc_auth.selfie'),
          }
        end

        def extra_attributes
          {
            liveness_score: liveness_score,
            acuant_error: acuant_error,
            liveness_assessment: liveness_assessment,
          }
        end

        def liveness_score
          parsed_response_body.dig('LivenessResult', 'Score')
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body)
        end

        def successful_result?
          liveness_assessment == 'Live'
        end

        def liveness_assessment
          parsed_response_body.dig('LivenessResult', 'LivenessAssessment')
        end
      end
    end
  end
end

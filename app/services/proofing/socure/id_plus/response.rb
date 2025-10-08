# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class Response
        UNKNOWN_REASON_CODE = '[unknown]'
        # @param [Faraday::Response] http_response
        def initialize(http_response)
          @http_response = http_response
        end

        def reference_id
          http_response.body['referenceId']
        end

        def customer_user_id
          http_response.body.dig('customerProfile', 'customerUserId')
        end

        private

        attr_reader :http_response

        def reason_codes_with_defnitions
          known_codes = SocureReasonCode.where(
            code: reason_codes,
          ).pluck(:code, :description).to_h
          reason_codes.index_with { |code| known_codes[code] || UNKNOWN_REASON_CODE }
        end

        def reason_codes
          raise NotImplementedError
        end
      end
    end
  end
end

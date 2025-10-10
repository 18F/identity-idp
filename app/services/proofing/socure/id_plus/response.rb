# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class Response
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

        def reason_codes
          raise NotImplementedError
        end
      end
    end
  end
end

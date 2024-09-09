# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class RequestError
      end

      class FetchResultsRequest
        def initialize(config:, results_id:)
          @api_key = config[:api_key]
          @results_id = results_id
        end

        def send_request
        end

        def body
        end

        def headers
          {
            'Content-Type' => 'application/json',
            'Authorization' => "SocureApiKey #{api_key}",
          }
        end

        private

        attr_reader :api_key
      end
    end
  end
end

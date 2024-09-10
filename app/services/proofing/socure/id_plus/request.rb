# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class RequestError < StandardError
        def initialize(wrapped)
          @wrapped = wrapped
          super(build_message)
        end

        def reference_id
          return @reference_id if defined?(@reference_id)
          @reference_id = response_body.is_a?(Hash) ?
            response_body['referenceId'] :
            nil
        end

        def response_body
          return @response_body if defined?(@response_body)
          @response_body = wrapped.try(:response_body)
        end

        def response_status
          return @response_status if defined?(@response_status)
          @response_status = wrapped.try(:response_status)
        end

        private

        attr_reader :wrapped

        def build_message
          message = response_body.is_a?(Hash) ? response_body['msg'] : nil
          message ||= wrapped.message
          status = response_status ? " (#{response_status})" : ''
          [message, status].join('')
        end
      end

      class Request
        SERVICE_NAME = 'socure_id_plus'

        def timeout_error?(err)
          err.is_a?(Faraday::TimeoutError) ||
            (err.is_a?(Faraday::ConnectionFailed) && err.wrapped_exception.is_a?(Net::OpenTimeout))
        end
      end
    end
  end
end

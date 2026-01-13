# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class Proofer
        attr_reader :config

        # @param [Proofing::Socure::IdPlus::Config] config
        # @param [Analytics,nil] analytics
        def initialize(config, analytics = nil)
          @config = config
          @analytics = analytics
        end

        # @param [Hash] applicant
        # @return [Proofing::Resolution::Result]
        def proof(applicant)
          input = Input.new(applicant.slice(*Input.members))
          response = request(input).send_request
          result = build_result_from_response(response)

          log_result(result.to_h)

          result
        rescue Proofing::TimeoutError, Request::Error => err
          NewRelic::Agent.notice_error(err)
          result = build_result_from_error(err)

          log_result(result.to_h)

          result
        end

        private

        def request(input)
          raise NotImplementedError
        end

        def build_result_from_response(response)
          raise NotImplementedError
        end

        def build_result_from_error(err)
          raise NotImplementedError
        end

        def log_result(result_hash)
          # No op
        end
      end
    end
  end
end

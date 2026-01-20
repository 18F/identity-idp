# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class Proofer
        attr_reader :config

        # @param [Proofing::Socure::IdPlus::Config] config
        def initialize(config)
          @config = config
        end

        # @param [Hash] applicant
        # @return [Proofing::Resolution::Result]
        def proof(applicant)
          input = Input.new(applicant.slice(*Input.members))
          response = request(input).send_request
          build_result_from_response(response)
        rescue Proofing::TimeoutError, Request::Error => err
          NewRelic::Agent.notice_error(err)
          build_result_from_error(err)
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
      end
    end
  end
end

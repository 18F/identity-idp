# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      class Proofer
        attr_reader :config

        def initialize(attrs)
          @config = Config.new(attrs)
        end

        def proof(applicant)
          response = verification_request(applicant).send_request
          build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          Proofing::DdpResult.new(success: false, exception: exception)
        end

        private

        def verification_request(applicant)
          raise NotImplementedError
        end

        def build_result_from_response(response)
          raise NotImplementedError
        end
      end
    end
  end
end

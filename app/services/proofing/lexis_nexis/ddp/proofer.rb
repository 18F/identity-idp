# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      class Proofer
        VALID_REVIEW_STATUSES = %w[pass review reject].freeze

        attr_reader :config

        def initialize(attrs)
          @config = Config.new(attrs)
        end

        def proof(applicant)
          response = verification_request.new(config: config, applicant: applicant).send_request
          puts response.inspect
          build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          Proofing::DdpResult.new(success: false, exception: exception)
        end

        private

        def validate_review_status!(review_status)
          return if VALID_REVIEW_STATUSES.include?(review_status)

          raise "Unexpected ThreatMetrix review_status value: #{review_status}"
        end

        def verification_request
          raise NotImplementedError
        end
      end
    end
  end
end

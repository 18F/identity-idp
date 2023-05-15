module Proofing
  module LexisNexis
    module InstantVerify
      class LoggingProofer < Proofer
        attr_reader :address_type

        def initialize(conf, address_type, enabled = true)
          super(conf)
          @address_type = address_type
          @enabled = enabled
        end

        # @param [Pii.Attributes] applicant
        # @return [Proofing::LexisNexis::Response]
        def send_request(applicant)
          request = VerificationRequest.new(config: config, applicant: applicant)
          body = JSON.parse(request.body)
          log_info_hash(
            {
              address_type: address_type,
              url: request.url,
              request_body: body,
            },
          )
          request.send_request
        end

        private

        def logger
          ActiveJob::Base.logger
        end

        def log_info_hash(msg)
          logger.info(
            {
              request: msg,
            }.to_json,
          )
        end
      end
    end
  end
end

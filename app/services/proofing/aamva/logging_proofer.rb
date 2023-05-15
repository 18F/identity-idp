# frozen_string_literal: true

module Proofing
  module Aamva
    class LoggingProofer < Proofing::Aamva::Proofer
      def initialize(config)
        super(config)
      end

      protected

      # @param [Object] aamva_applicant
      # @return [Proofing::Aamva::Response::VerificationResponse] proofing result
      def make_request(aamva_applicant)
        client = Aamva::VerificationClient.new(
          config,
        )
        request = client.get_verification_request(aamva_applicant, nil)
        log_info_hash(
          {
            url: request.url,
            body: request.body,
            headers: request.headers,
          },
        )
        request.send
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

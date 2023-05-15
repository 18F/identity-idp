# frozen_string_literal: true

module Proofing
  module Aamva
    class NoopProofer < Proofing::Aamva::Proofer
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
        build_raw_response(200, AamvaFixtures.verification_response)
      end

      private

      # @param [Integer] status_code http numeric status code
      # @param [Object] response_body xml string of AAMVA response body
      # @return [Proofing::Aamva::Response::VerificationResponse]
      def build_raw_response(status_code, response_body)
        headers = { 'Content-Type' => 'application/xml' }
        env = {
          response_body: response_body,
          request_headers: Faraday::Utils::Headers.new,
          response_headers: Faraday::Utils::Headers.new(headers),
          status: status_code,
        }
        farady_response = Faraday::Response.new(env)
        Proofing::Aamva::Response::VerificationResponse.new(farady_response)
      end

      def logger
        ActiveJob::Base.logger
      end

      def log_info_hash(msg)
        logger.info(
          {
            message: msg,
          }.to_json,
        )
      end
    end
  end
end

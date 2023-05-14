# frozen_string_literal: true

module Proofing
  module Aamva
    class NoopProofer < Proofing::Aamva::Proofer
      def initialize(config)
        super(config)
      end

      # @param [Pii::Attributes] applicant
      # @return [Proofing::StateIdResult]
      def proof(applicant)
        aamva_applicant =
          Aamva::Applicant.from_proofer_applicant(OpenStruct.new(applicant))
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
        raw_response = build_raw_response(200, AamvaFixtures.verification_response)
        build_result_from_response(raw_response)
      rescue => exception
        NewRelic::Agent.notice_error(exception)
        Proofing::StateIdResult.new(
          success: false, errors: {}, exception: exception, vendor_name: 'aamva:state_id',
          transaction_id: nil, verified_attributes: []
        )
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

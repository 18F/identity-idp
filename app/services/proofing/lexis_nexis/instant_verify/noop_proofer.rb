module Proofing
  module LexisNexis
    module InstantVerify
      class NoopProofer < Proofer
        attr_accessor :address_type

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
          # To-do: log request body
          log_info_hash(
            {
              url: request.url,
              requestBody: body,
            },
          )
          scenario = map_applicant_to_scenario(applicant)
          respose_body = NoopProofer.scenario_responses[scenario]
          build_raw_response(200, respose_body)
        end

        private

        # @param [Pii:Attributes] applicant
        # @return [Symbol] the scenario for the applicnt
        def map_applicant_to_scenario(applicant)
          last_name = applicant[:last_name]
          case last_name
          when /IVSuccess$/i
            :success
          when /IVFailure$/i
            :failure
          when /IVFailureWithAAMVA$/i
            :failure_with_aamva
          when /IVFailureWithoutAAMVA$/i
            :failure_without_aamva
          else
            :success
          end
        end

        # @param [Integer] statusCode
        # @param [Object] response_body, the JSON response body
        def build_raw_response(status_code, response_body)
          headers = { 'Content-Type' => 'application/json' }
          env = {
            response_body: JSON.generate(response_body),
            request_headers: Faraday::Utils::Headers.new,
            response_headers: Faraday::Utils::Headers.new(headers),
            status: status_code,
          }
          farady_response = Faraday::Response.new(env)
          Proofing::LexisNexis::Response.new(farady_response)
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

        # @return [Hash]
        private_class_method def self.build_scenario_responses
          data = {}
          data.default_proc = proc do |_, key|
            case key
            when :success
              JSON.parse(LexisNexisFixtures.instant_verify_success_response_json)
            when :failure
              JSON.parse(LexisNexisFixtures.instant_verify_address_fail_response_json)
            when :failure_with_aamva
              JSON.parse(LexisNexisFixtures.instant_verify_date_of_birth_and_address_fail_response_json)
            when :failure_without_aamva
              JSON.parse(LexisNexisFixtures.instant_verify_identity_not_found_response_json)
            else
              nil
            end
          end
          data
        end


        private_class_method def self.scenario_responses
          # only initialize once
          #noinspection RubyClassVariableUsageInspection
          @@scenario_responses ||= build_scenario_responses
        end
      end
    end
  end
end

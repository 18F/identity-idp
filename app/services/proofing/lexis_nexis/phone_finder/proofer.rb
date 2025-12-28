# frozen_string_literal: true

module Proofing
  module LexisNexis
    module PhoneFinder
      class Proofer
        include AbTestingConcern

        attr_reader :config

        def initialize(config)
          @config = LexisNexis::Config.new(config)
        end

        def proof(applicant)
          response = verification_request(config: config, applicant: applicant).send_request
          build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          AddressResult.new(
            success: false,
            errors: {},
            exception: exception,
            vendor_name: 'lexisnexis:phone_finder',
          )
        end

        private

        def verification_request(config:, applicant:)
          rdp_version = ab_test_bucket(
            :PHONE_FINDER_RDP_VERSION,
            user: user(applicant[:uuid]),
            service_provider: nil,
            current_session: nil,
            current_user_session: nil,
          ) || IdentityConfig.store.idv_rdp_version_default

          case rdp_version
          when :rdp_v3
            VerificationRequestRdpV3.new(config: config, applicant: applicant)
          else
            VerificationRequest.new(config: config, applicant: applicant)
          end
        end

        def user(uuid)
          User.find_by(uuid:)
        end

        def build_result_from_response(verification_response)
          AddressResult.new(
            success: verification_response.verification_status == 'passed',
            errors: parse_verification_errors(verification_response),
            exception: nil,
            vendor_name: 'lexisnexis:phone_finder',
            transaction_id: verification_response.conversation_id,
            reference: verification_response.reference,
            vendor_workflow: config.phone_finder_workflow,
          )
        end

        def parse_verification_errors(verification_response)
          errors = Hash.new { |h, k| h[k] = [] }
          verification_response.verification_errors.each do |key, value|
            errors[key] << value
          end
          errors
        end
      end
    end
  end
end

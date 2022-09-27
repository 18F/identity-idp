# require 'ostruct'
# require 'redacted_struct'

module Proofing
  module Aamva
    class Proofer
      Config = RedactedStruct.new(
        :auth_request_timeout,
        :auth_url,
        :cert_enabled,
        :private_key,
        :public_key,
        :verification_request_timeout,
        :verification_url,
        keyword_init: true,
        allowed_members: [
          :auth_request_timeout,
          :auth_url,
          :cert_enabled,
          :verification_request_timeout,
          :verification_url,
        ],
      )

      attr_reader :config

      def initialize(config)
        @config = Config.new(config)
      end

      def proof(applicant)
        response = VerificationRequest.new(config: config, applicant: applicant).send
        return Proofing::LexisNexis::Aamva::Result.new(response)
      rescue => exception
        NewRelic::Agent.notice_error(exception)
        ResultWithException.new(exception, vendor_name: 'lexisnexis:phone_finder')
      end

      def aamva_proof(applicant, result)
        aamva_applicant = Aamva::Applicant.from_proofer_applicant(OpenStruct.new(applicant))
        response = Aamva::VerificationClient.new(config).
          send_verification_request(applicant: aamva_applicant)
        result.transaction_id = response.transaction_locator_id
        unless response.success?
          response.verification_results.each do |attribute, v_result|
            result.add_error(attribute.to_sym, 'UNVERIFIED') if v_result == false
            result.add_error(attribute.to_sym, 'MISSING') if v_result.nil?
          end
        end
      end

      # def vendor_name
      #   'aamva:state_id'
      # end

      # required_attributes(
      #   :uuid,
      #   :first_name,
      #   :last_name,
      #   :dob,
      #   :state_id_number,
      #   :state_id_type,
      #   :state_id_jurisdiction,
      # )

      # optional_attributes :uuid_prefix

      # stage :state_id

      # proof :aamva_proof
    end
  end
end

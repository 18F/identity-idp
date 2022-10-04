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

      # Instance methods
      def initialize(config)
        @config = Config.new(config)
      end

      def proof(applicant)
        aamva_applicant =
          Aamva::Applicant.from_proofer_applicant(OpenStruct.new(applicant))
        verification_response = Aamva::VerificationClient.new(
          config,
        ).send_verification_request(
          applicant: aamva_applicant,
        )
        build_result_from_response(verification_response)
      rescue => exception
        NewRelic::Agent.notice_error(exception)
        Proofing::StateIdResult.new(
          success: false, errors: {}, exception: exception, vendor_name: 'aamva:state_id',
          transaction_id: nil, verified_attributes: []
        )
      end

      private

      def build_result_from_response(verification_response)
        Proofing::StateIdResult.new(
          success: verification_response.success?,
          errors: parse_verification_errors(verification_response),
          exception: nil,
          vendor_name: 'aamva:state_id',
          transaction_id: verification_response.transaction_locator_id,
          verified_attributes: verified_attributes(verification_response),
        )
      end

      def parse_verification_errors(verification_response)
        errors = {}
        return errors if verification_response.success?

        verification_response.verification_results.each do |attribute, v_result|
          attribute_key = attribute.to_sym
          next if v_result == true
          errors[attribute_key] ||= []
          errors[attribute_key].push('UNVERIFIED') if v_result == false
          errors[attribute_key].push('MISSING') if v_result.nil?
        end
        errors
      end

      def verified_attributes(verification_response)
        attributes = Set.new
        results = verification_response.verification_results

        attributes.add :address if address_verified?(results)

        results.delete :address1
        results.delete :address2
        results.delete :city
        results.delete :state
        results.delete :zipcode

        results.each do |attribute, verified|
          attributes.add attribute if verified
        end

        attributes
      end

      def address_verified?(results)
        results[:address1] &&
          results[:city] &&
          results[:state] &&
          results[:zipcode]
      end
    end
  end
end

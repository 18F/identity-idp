module Proofing
  module LexisNexis
    # Verifies through the RDP platform
    module InstantVerify
      class Proofer < LexisNexis::Proofer
        vendor_name 'lexisnexis:instant_verify'

        required_attributes :uuid,
                            :first_name,
                            :last_name,
                            :dob,
                            :ssn,
                            :address1,
                            :city,
                            :state,
                            :zipcode

        optional_attributes :address2, :uuid_prefix

        stage :resolution

        proof do |applicant, result|
          proof_applicant(applicant, result)
        end

        def send_verification_request(applicant)
          VerificationRequest.new(config: config, applicant: applicant).send(
            response_options: {
              dob_year_only: applicant[:dob_year_only],
            },
          )
        end
      end
    end
  end
end

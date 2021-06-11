module Proofing
  module LexisNexis
    module PhoneFinder
      class Proofer < LexisNexis::Proofer
        vendor_name 'lexisnexis:phone_finder'

        required_attributes :uuid,
                            :first_name,
                            :last_name,
                            :dob,
                            :ssn,
                            :phone

        optional_attributes :uuid_prefix

        stage :address

        proof do |applicant, result|
          proof_applicant(applicant, result)
        end

        def send_verification_request(applicant)
          VerificationRequest.new(config: config, applicant: applicant).send
        end
      end
    end
  end
end

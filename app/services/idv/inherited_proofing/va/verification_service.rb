module Idv
  module InheritedProofing
    module Va
      class VerificationService
        # def send_verification_request(applicant)
        # VerificationRequest.new(config: config, applicant: applicant).send

        # instantiate proofer instance with config
        # call proof method on proofer with applicant object
        # handle result

        def initialize(config)
          @config = config
        end

        def verify_phone(applicant)
          # proofer = Proofing::LexisNexis::PhoneFinder::Proofer.new(@config)
          # result = proofer.proof(applicant)
          # do something with the result
          proofer = VerificationRequest.new(config: @config, applicant: applicant).send
        end
      end
    end
  end
end

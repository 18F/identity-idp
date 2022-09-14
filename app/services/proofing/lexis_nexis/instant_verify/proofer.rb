module Proofing
  module LexisNexis
    module InstantVerify
      class Proofer
        attr_reader :config

        def initialize(config)
          @config = LexisNexis::Proofer::Config.new(config)
        end

        def proof(applicant)
          response = VerificationRequest.new(config: config, applicant: applicant).send
          return Proofing::LexisNexis::InstantVerify::Result.new(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          ResultWithException.new(exception, vendor_name: 'lexisnexis:instant_verify')
        end
      end
    end
  end
end

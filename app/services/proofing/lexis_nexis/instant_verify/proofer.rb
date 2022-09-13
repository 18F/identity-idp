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
          return Proofing::LexisNexis::LexisNexis::Result.new(response) # TODO: Make this result class
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          ResultWithException.new(exception) # TODO: Make this class too
        end
      end
    end
  end
end

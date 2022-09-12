module Proofing
  module LexisNexis
    module PhoneFinder
      class Proofer #< LexisNexis::Proofer
        attr_reader :config

        def initialize(config)
          @config = LexisNexis::Proofer::Config.new(config)
        end

        def proof(applicant)
          response = VerificationRequest.new(config: config, applicant: applicant).send
          return Proofing::LexisNexis::PhoneFinder::Result.new(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          ResultWithException.new(exception)
        end
      end
    end
  end
end

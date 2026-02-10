# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Requests
        class ThreatMetrixRequest < Proofing::LexisNexis::Ddp::VerificationRequest
          private

          def timeout
            IdentityConfig.store.lexisnexis_threatmetrix_timeout
          end

          def session_id
            applicant[:threatmetrix_session_id]
          end
        end
      end
    end
  end
end

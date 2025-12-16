# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Requests
        class InstantVerifyRequest < VerificationRequest
          private

          def metric_name
            'lexis_nexis_ddp_instant_verify'
          end

          def url_request_path
            '/api/attribute-query'
          end

          def timeout
            IdentityConfig.store.lexisnexis_threatmetrix_timeout
          end
        end
      end
    end
  end
end

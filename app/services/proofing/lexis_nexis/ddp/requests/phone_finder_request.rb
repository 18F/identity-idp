# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Requests
        class PhoneFinderRequest < VerificationRequest
          private

          def metric_name
            'lexis_nexis_ddp_phone_finder'
          end

          def url_request_path
            '/api/attribute-query'
          end

          # def timeout
          #   IdentityConfig.store.lexisnexis_threatmetrix_timeout
          # end
        end
      end
    end
  end
end

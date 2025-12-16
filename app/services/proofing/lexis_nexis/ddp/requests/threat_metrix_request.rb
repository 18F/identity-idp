# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Requests
        class ThreatMetrixRequest < Request
          private

          def metric_name
            'lexis_nexis_ddp' # ..._tmx
          end

          def url_request_path
            '/api/session-query'
          end

          def timeout
            IdentityConfig.store.lexisnexis_threatmetrix_timeout
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      class VerificationRequest < Request
        private

        def metric_name
          'lexis_nexis_ddp'
        end

        def url_request_path
          '/api/session-query'
        end
      end
    end
  end
end

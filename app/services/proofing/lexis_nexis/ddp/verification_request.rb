# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      class VerificationRequest < Request
        private

        def build_request_body
          raise NotImplementedError
        end

        def metric_name
          raise NotImplementedError
        end

        def url_request_path
          raise NotImplementedError
        end

        def verification_request
          raise NotImplementedError
        end

        def timeout
          IdentityConfig.store.lexisnexis_threatmetrix_timeout
        end
      end
    end
  end
end

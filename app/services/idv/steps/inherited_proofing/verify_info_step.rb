module Idv
  module Steps
    module InheritedProofing
      class VerifyInfoStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :verify_phone
        def call
          Rails.logger.debug('xyzzy: in VerifyInfoStep')
        end
      end
    end
  end
end

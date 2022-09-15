module Idv
  module Steps
    module InheritedProofing
      class PhoneStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          Rails.logger.debug('xyzzy: in PhoneStep')
        end
      end
    end
  end
end

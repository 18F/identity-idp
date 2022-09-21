module Idv
  module Steps
    module InheritedProofing
      class PhoneStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :verify_phone
        def call
          Rails.logger.info('DEBUG: entering PhoneStep#call')
        end
      end
    end
  end
end

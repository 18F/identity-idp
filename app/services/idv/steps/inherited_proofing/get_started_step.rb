module Idv
  module Steps
    module InheritedProofing
      class GetStartedStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :getting_started
        def call
          Rails.logger.debug('xyzzy: in GetStartedStep')
        end
      end
    end
  end
end

module Idv
  module Steps
    module InheritedProofing
      class VerifyWaitStep < InheritedProofingBaseStep
        include UserPiiManagable

        STEP_INDICATOR_STEP = :getting_started

        def call; end
      end
    end
  end
end

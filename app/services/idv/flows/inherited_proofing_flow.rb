module Idv
  module Flows
    class InheritedProofingFlow < Flow::BaseFlow
      STEPS = {
        get_started: Idv::Steps::InheritedProofing::GetStartedStep,
      }.freeze

      STEP_INDICATOR_STEPS = [
        { name: :getting_started },
      ].freeze

      ACTIONS = {}.freeze

      def initialize(controller, session, name)
        super(controller, STEPS, ACTIONS, session[name])
      end
    end
  end
end

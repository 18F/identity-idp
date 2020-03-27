module Px
  module Flows
    class VerifyFlow < Flow::BaseFlow
      STEPS = {
        basic_info: Px::Steps::BasicInfoStep,
      }.freeze

      def initialize(controller, session, _name)
        super(controller, STEPS, {}, session)
      end
    end
  end
end

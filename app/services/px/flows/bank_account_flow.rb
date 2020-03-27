module Px
  module Flows
    class BankAccountFlow < Flow::BaseFlow
      STEPS = {
        bank_account_info: Px::Steps::BankAccountInfoStep,
      }.freeze

      def initialize(controller, session, _name)
        super(controller, STEPS, {}, session)
      end
    end
  end
end

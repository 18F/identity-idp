module Px
  module Steps
    class OtpVerificationStep < Px::Steps::PxBaseStep
      def call
        # TODO: Rate limit the user
        # TODO: Verify the OTP
      end
    end
  end
end

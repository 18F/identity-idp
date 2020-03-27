module Px
  module Steps
    class OtpDeliveryMethodStep < Px::Steps::PxBaseStep
      def form_submit
        Idv::OtpDeliveryMethodForm.new.submit(otp_delivery_method_params)
      end

      def call
        # Throttle OTP sends
        # Send the OTP
      end

      private

      def otp_delivery_method_params
        params.permit(:otp_delivery_preference)
      end
    end
  end
end

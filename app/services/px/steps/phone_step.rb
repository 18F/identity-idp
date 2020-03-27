module Px
  module Steps
    class PhoneStep < Px::Steps::PxBaseStep
      def form_submit
        Idv::PhoneForm.new(user: current_user, previous_params: {}).submit(phone_params)
      end

      def call
        # Throttle attempts
        # Verify the phone
        # Mark OTP methods complete if the users uses OTP phone
      end

      private

      def phone_params
        params.require(:idv_phone_form).permit(:phone)
      end
    end
  end
end

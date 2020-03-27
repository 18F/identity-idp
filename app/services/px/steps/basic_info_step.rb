module Px
  module Steps
    class BasicInfoStep < Px::Steps::PxBaseStep
      def form_submit
        BasicInfoForm.new.submit(basic_info_params)
      end

      def call
        # Verify the submitted info here
      end

      private

      def basic_info_params
        params.require(:px_basic_info_form).permit(
          :first_name,
          :last_name,
          :dob, :ssn,
          :address1,
          :address2,
          :city,
          :state,
          :zipcode
        )
      end
    end
  end
end

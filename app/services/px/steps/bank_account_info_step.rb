module Px
  module Steps
    class BankAccountInfoStep < Px::Steps::PxBaseStep
      def form_submit
        Px::BankAccountInfoForm.new.submit(bank_account_info_params)
      end

      def call; end

      private

      def bank_account_info_params
        params.require(:px_bank_account_info_form).permit(
          :routing_number,
          :account_number,
        )
      end
    end
  end
end

module Idv
  module Steps
    class RecoverDocSuccessStep < DocAuthBaseStep
      def call
        pii_from_doc = session['idv/recovery']['pii_from_doc']
        decrypted_pii = JSON.parse(saved_pii)
        return unless pii_matches_data_on_file?(pii_from_doc, decrypted_pii)

        mark_step_complete(:recover_fail)
        redirect_to account_url
        session['need_two_factor_authentication'] = false
      end

      private

      def saved_pii
        session['decrypted_pii']
      end

      def pii_matches_data_on_file?(pii_from_doc, decrypted_pii)
        %w[first_name last_name dob ssn].each do |key|
          return false unless pii_from_doc[key] == decrypted_pii[key]
        end
        true
      end
    end
  end
end

module Idv
  module Steps
    module Ipp
      class AddressStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          Idv::InPersonProofingAddressForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end
        end

        def extra_view_variables
          {
            pii: flow_session[:pii_from_user],
          }
        end

        private

        def form_submit
          Idv::InPersonProofingAddressForm.new.submit(
            permit(*Idv::InPersonProofingAddressForm::ATTRIBUTES),
          )
        end
      end
    end
  end
end

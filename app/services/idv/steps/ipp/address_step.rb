module Idv
  module Steps
    module Ipp
      class AddressStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        FIELDS = [*AddressForm::ATTRIBUTES, :same_address_as_id]

        def call
          flow_session[:pii_from_user].merge!(flow_params.permit(*FIELDS).slice(*FIELDS))
        end

        def extra_view_variables
          {
            pii: flow_session[:pii_from_user],
          }
        end

        private

        def form_submit
          Idv::InPersonProofingAddressForm.new(current_user).submit(
            permit(*FIELDS),
          )
        end
      end
    end
  end
end

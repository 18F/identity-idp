module Idv
  module Steps
    module InPerson
      class AddressStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          Idv::InPerson::AddressForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end
        end

        def extra_view_variables
          {
            pii: flow_session[:pii_from_user],
            updating_address: flow_session[:pii_from_user].has_key?(:address1),
          }
        end

        private

        def form_submit
          Idv::InPerson::AddressForm.new.submit(
            permit(*Idv::InPerson::AddressForm::ATTRIBUTES),
          )
        end
      end
    end
  end
end

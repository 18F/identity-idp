module Idv
  module Steps
    module Ipp
      class AddressStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        FIELDS = [
          :address1, :address2, :city, :state,
          :zipcode
        ]

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
          Idv::AddressForm.new(current_user).submit(
            permit(*FIELDS),
          )
        end
      end
    end
  end
end

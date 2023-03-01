module Idv
  module Steps
    module InPerson
      class ResidentialAddressStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def self.analytics_visited_event
          :idv_in_person_proofing_residential_address_visited
        end

        def self.analytics_submitted_event
          :idv_in_person_proofing_residential_address_submitted
        end

        def call
          Idv::InPerson::ResidentialAddressForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end

          if IdentityConfig.store.in_person_capture_secondary_id_enabled
            mark_step_complete(:address)
          end
        end

        def extra_view_variables
          {
            pii: flow_session[:pii_from_user],
          }
        end

        private

        def form_submit
          Idv::InPerson::ResidentialAddressForm.new.submit(
            permit(*Idv::InPerson::ResidentialAddressForm::ATTRIBUTES),
          )
        end
      end
    end
  end
end

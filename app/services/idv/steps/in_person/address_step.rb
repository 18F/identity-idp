module Idv
  module Steps
    module InPerson
      class AddressStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def self.analytics_visited_event
          :idv_in_person_proofing_address_visited
        end

        def analytics_submitted_event
          if capture_secondary_id_enabled?
            :idv_in_person_proofing_residential_address_submitted
          else
            :idv_in_person_proofing_address_submitted
          end
        end

        def call
          Idv::InPerson::AddressForm::ATTRIBUTES.each do |attr|
            next if attr == :same_address_as_id && capture_secondary_id_enabled?
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end
          exit_flow_state_machine if avoid_fsm?
        end

        def extra_view_variables
          {
            capture_secondary_id_enabled: capture_secondary_id_enabled?,
            form:,
            pii:,
            updating_address:,
          }
        end

        private

        def capture_secondary_id_enabled?
          current_user.establishing_in_person_enrollment.capture_secondary_id_enabled
        end

        def updating_address
          flow_session[:pii_from_user].has_key?(:address1)
        end

        def pii
          data = flow_session[:pii_from_user]
          data = data.merge(flow_params) if params.has_key?(:in_person_address)
          data.deep_symbolize_keys
        end

        def flow_params
          params.require(:in_person_address).permit(
            *Idv::InPerson::AddressForm::ATTRIBUTES,
          )
        end

        def form
          @form ||= Idv::InPerson::AddressForm.
            new(capture_secondary_id_enabled: capture_secondary_id_enabled?)
        end

        def form_submit
          form.submit(flow_params)
        end
      end
    end
  end
end

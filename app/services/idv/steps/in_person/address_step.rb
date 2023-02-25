module Idv
  module Steps
    module InPerson
      class AddressStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def self.analytics_visited_event
          :idv_in_person_proofing_address_visited
        end

        def self.analytics_submitted_event
          :idv_in_person_proofing_address_submitted
        end

        def call
          Idv::InPerson::AddressForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end
        end

        def extra_view_variables
          {
            form:,
            pii: flow_session[:pii_from_user],
            updating_address: flow_session[:pii_from_user].has_key?(:address1),
          }
        end

        private

        def flow_params
          params.require(:in_person_address).permit(
            # params.permit(
            *Idv::InPerson::AddressForm::ATTRIBUTES,
          )
        end

        def form
          @form ||= Idv::InPerson::AddressForm.new
        end

        def form_submit
          form.submit(flow_params)
        end
      end
    end
  end
end

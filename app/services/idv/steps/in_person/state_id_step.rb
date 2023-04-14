module Idv
  module Steps
    module InPerson
      class StateIdStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def self.analytics_visited_event
          :idv_in_person_proofing_state_id_visited
        end

        def self.analytics_submitted_event
          :idv_in_person_proofing_state_id_submitted
        end

        def call
          pii_from_user = flow_session[:pii_from_user]
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end
          # Accept Date of Birth from both memorable date and input date components
          formatted_dob = MemorableDateComponent.extract_date_param flow_params&.[](:dob)
          pii_from_user[:dob] = formatted_dob if formatted_dob
          if capture_secondary_id_enabled? && pii_from_user[:same_address_as_id] == 'true'
            pii_from_user[:address1] = flow_params[:identity_doc_address1]
            pii_from_user[:address2] = flow_params[:identity_doc_address2]
            pii_from_user[:city] = flow_params[:identity_doc_city]
            pii_from_user[:state] = flow_params[:identity_doc_state]
            pii_from_user[:zipcode] = flow_params[:identity_doc_zipcode]
            mark_step_complete(:address)
          end
        end

        def extra_view_variables
          {
            capture_secondary_id_enabled: capture_secondary_id_enabled?,
            form:,
            pii:,
            parsed_dob:,
            updating_state_id:,
          }
        end

        private

        def capture_secondary_id_enabled?
          current_user.establishing_in_person_enrollment.capture_secondary_id_enabled
        end

        def updating_state_id
          flow_session[:pii_from_user].has_key?(:first_name)
        end

        def parsed_dob
          form_dob = pii[:dob]
          if form_dob.instance_of?(String)
            dob_str = form_dob
          elsif form_dob.instance_of?(Hash)
            dob_str = MemorableDateComponent.extract_date_param(form_dob)
          end
          Date.parse(dob_str) unless dob_str.nil?
        rescue StandardError
          # Catch date parsing errors
        end

        def pii
          data = flow_session[:pii_from_user]
          data = data.merge(flow_params) if params.has_key?(:state_id)
          data.deep_symbolize_keys
        end

        def flow_params
          params.require(:state_id).permit(
            *Idv::StateIdForm::ATTRIBUTES,
            dob: [
              :month,
              :day,
              :year,
            ],
          )
        end

        def form
          @form ||= Idv::StateIdForm.new(current_user)
        end

        def form_submit
          form.submit(flow_params)
        end
      end
    end
  end
end

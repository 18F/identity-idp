# frozen_string_literal: true

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
          initial_state_of_same_address_as_id = flow_session[:pii_from_user][:same_address_as_id]
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end
          # Accept Date of Birth from both memorable date and input date components
          formatted_dob = MemorableDateComponent.extract_date_param flow_params&.[](:dob)
          pii_from_user[:dob] = formatted_dob if formatted_dob

          if pii_from_user[:same_address_as_id] == 'true'
            copy_state_id_address_to_residential_address(pii_from_user)
            redirect_to idv_in_person_ssn_url
          end

          if initial_state_of_same_address_as_id == 'true' &&
             pii_from_user[:same_address_as_id] == 'false'
            clear_residential_address(pii_from_user)
         end

          redirect_to idv_in_person_verify_info_url if updating_state_id?

          if pii_from_user[:same_address_as_id] == 'false'
            redirect_to idv_in_person_address_url
          end
        end

        def extra_view_variables
          {
            form:,
            pii:,
            parsed_dob:,
            updating_state_id: updating_state_id?,
          }
        end

        private

        def clear_residential_address(pii_from_user)
          pii_from_user.delete(:address1)
          pii_from_user.delete(:address2)
          pii_from_user.delete(:city)
          pii_from_user.delete(:state)
          pii_from_user.delete(:zipcode)
        end

        def copy_state_id_address_to_residential_address(pii_from_user)
          pii_from_user[:address1] = flow_params[:identity_doc_address1]
          pii_from_user[:address2] = flow_params[:identity_doc_address2]
          pii_from_user[:city] = flow_params[:identity_doc_city]
          pii_from_user[:state] = flow_params[:identity_doc_address_state]
          pii_from_user[:zipcode] = flow_params[:identity_doc_zipcode]
        end

        def updating_state_id?
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
          if params.has_key?(:identity_doc) || params.has_key?(:state_id)
            data = data.merge(flow_params)
          end
          data.deep_symbolize_keys
        end

        def flow_params
          if params.dig(:identity_doc).present?
            # Transform the top-level params key to accept the renamed form
            # for autofill handling workaround
            params[:state_id] = params.delete(:identity_doc)

            # Rename nested id_number to state_id_number
            if params[:state_id][:id_number].present?
              params[:state_id][:state_id_number] = params[:state_id].delete(:id_number)
            end
          end

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

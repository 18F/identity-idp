module Idv
  module Steps
    module InPerson
      class StateIdStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end

          # Accept Date of Birth from both memorable date and input date components
          formatted_dob = MemorableDateComponent.extract_date_param flow_params&.[](:dob)
          flow_session[:pii_from_user][:dob] = formatted_dob if formatted_dob
        end

        def extra_view_variables
          parsed_dob = nil
          if flow_session[:pii_from_user][:dob].instance_of? String
            parsed_dob = Date.parse flow_session[:pii_from_user][:dob]
          end

          {
            pii: flow_session[:pii_from_user],
            parsed_dob: parsed_dob,
            updating_state_id: flow_session[:pii_from_user].has_key?(:first_name),
          }
        end

        private

        def form_submit
          Idv::StateIdForm.new(current_user).submit(
            permit(
              *Idv::StateIdForm::ATTRIBUTES,
              dob: [
                :month,
                :day,
                :year,
              ],
            ),
          )
        end
      end
    end
  end
end

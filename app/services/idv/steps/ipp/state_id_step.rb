module Idv
  module Steps
    module Ipp
      class StateIdStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end

          # Accept Date of Birth from both memorable date and input date components
          fp = flow_params&.[](:dob)
          if !(fp.instance_of? String || fp.empty?)
            formatted_dob = "#{fp&.[](:year)}-#{fp&.[](:month)&.rjust(2,'0')}-#{fp&.[](:day)&.rjust(2,'0')}"
            if /^\d{4}-\d{2}-\d{2}$/.match? formatted_dob
              flow_session[:pii_from_user][:dob] = formatted_dob
            end
          end
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
          Idv::StateIdForm.new(current_user).submit(permit(
            *Idv::StateIdForm::ATTRIBUTES,
            :dob => [
              :month,
              :day,
              :year,
            ],
          ))
        end
      end
    end
  end
end

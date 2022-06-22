module Idv
  module Steps
    module Ipp
      class StateIdStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            flow_session[:pii_from_user][attr] = flow_params[attr]
          end
        end

        def extra_view_variables
          {
            pii: flow_session[:pii_from_user],
            updating_state_id: flow_session[:pii_from_user].has_key?(:first_name),
          }
        end

        private

        def form_submit
          Idv::StateIdForm.new(current_user).submit(permit(*Idv::StateIdForm::ATTRIBUTES))
        end
      end
    end
  end
end

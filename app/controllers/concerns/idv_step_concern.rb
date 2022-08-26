module IdvStepConcern
  extend ActiveSupport::Concern

  include IdvSession

  included do
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_idv_session_started
  end

  def step_indicator_steps
    if in_person_proofing_session?
      if gpo_address_verification?
        Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS_GPO
      else
        Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS
      end
    else
      if gpo_address_verification?
        Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS_GPO
      else
        Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS
      end
    end
  end
end

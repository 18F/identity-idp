# frozen_string_literal: true

class Idv::InPerson::ChooseIdTypePresenter < Idv::ChooseIdTypePresenter
  def choose_id_type_info_text
    t('in_person_proofing.info.choose_id_type')
  end

  def current_step
    :verify_info
  end

  def step_indicator_steps
    Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_IPP
  end
end

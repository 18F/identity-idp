# frozen_string_literal: true

class Idv::InPerson::ChooseIdTypePresenter
  include ActionView::Helpers::TranslationHelper

  def choose_id_type_info_text
    t('in_person_proofing.info.choose_id_type')
  end

  def current_step
    :verify_info
  end

  def hybrid_flow?
    false
  end

  def step_indicator_steps
    Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_IPP
  end
end

# frozen_string_literal: true

class Idv::ChooseIdTypePresenter
  include ActionView::Helpers::TranslationHelper

  def choose_id_type_info_text
    t('doc_auth.info.choose_id_type')
  end

  def current_step
    :verify_id
  end

  def hybrid_flow?
    false
  end

  def step_indicator_steps
    Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS
  end
end

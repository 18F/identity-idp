# frozen_string_literal: true

class Idv::InPerson::VerifyInfoPresenter
  def initialize(enrollment:)
    @enrollment = enrollment
  end

  def step_indicator_steps
    Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_IPP
  end

  def identity_info_partial
    passport_flow? ? 'passport_section' : 'state_id_section'
  end

  def passport_flow?
    @enrollment.passport_book?
  end
end

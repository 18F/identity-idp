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

  def show_state_id_expiration?
    IdentityConfig.store.in_person_proofing_expiration_edge_cases_enabled
  end

  # Human-readable expiration value for the verify-info screen, handling the
  # edge-case sentinels and literal placeholder dates.
  def formatted_state_id_expiration(pii)
    value = pii[:state_id_expiration]
    return if value.blank?

    case value
    when Idv::StateIdForm::EXPIRATION_MILITARY
      I18n.t('in_person_proofing.form.state_id.expiration_date_options.military')
    when Idv::StateIdForm::EXPIRATION_INDEFINITE
      I18n.t('in_person_proofing.form.state_id.expiration_date_options.indefinite')
    when Idv::StateIdForm::EXPIRATION_NONE
      I18n.t('in_person_proofing.form.state_id.expiration_date_options.other')
    when '9999-99-99'
      '99/99/9999'
    when '0000-00-00'
      '00/00/0000'
    else
      date = begin
        Date.parse(value)
      rescue Date::Error
        nil
      end
      date ? I18n.l(date, format: I18n.t('time.formats.event_date')) : value
    end
  end
end

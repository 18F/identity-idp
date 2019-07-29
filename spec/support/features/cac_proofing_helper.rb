module CacProofingHelper
  def idv_cac_proofing_welcome_step
    idv_cac_step_path(step: :welcome)
  end

  def idv_cac_proofing_present_cac_step
    idv_cac_step_path(step: :present_cac)
  end

  def idv_cac_proofing_enter_info_step
    idv_cac_step_path(step: :enter_info)
  end

  def idv_cac_proofing_verify_step
    idv_cac_step_path(step: :verify)
  end

  def enable_cac_proofing
    allow(Figaro.env).to receive(:cac_proofing_enabled).and_return('true')
  end

  def complete_cac_proofing_steps_before_welcome_step
    visit idv_cac_proofing_welcome_step
  end

  def complete_cac_proofing_steps_before_present_cac_step
    complete_cac_proofing_steps_before_welcome_step
    click_on t('doc_auth.buttons.get_started')
  end

  def complete_cac_proofing_steps_before_enter_info_step
    complete_cac_proofing_steps_before_present_cac_step
    click_continue
  end

  def complete_cac_proofing_steps_before_verify_step
    complete_cac_proofing_steps_before_enter_info_step
    click_continue
  end

  def complete_cac_proofing_steps_before_success_step
    complete_cac_proofing_steps_before_verify_step
    click_continue
  end
end

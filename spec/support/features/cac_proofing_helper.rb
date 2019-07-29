module CacProofingHelper
  def idv_cac_proofing_welcome_step
    idv_cac_step_path(step: :welcome)
  end

  def idv_cac_proofing_find_usps_step
    idv_cac_step_path(step: :find_usps)
  end

  def idv_cac_proofing_usps_list_step
    idv_cac_step_path(step: :usps_list)
  end

  def idv_cac_proofing_enter_info_step
    idv_cac_step_path(step: :enter_info)
  end

  def idv_cac_proofing_verify_step
    idv_cac_step_path(step: :verify)
  end

  def idv_cac_proofing_encrypt_step
    idv_cac_step_path(step: :encrypt)
  end

  def idv_cac_proofing_bar_code_step
    idv_cac_step_path(step: :bar_code)
  end

  def enable_cac_proofing
    allow(Figaro.env).to receive(:cac_proofing_enabled).and_return('true')
  end

  def complete_cac_proofing_steps_before_welcome_step
    visit idv_cac_proofing_welcome_step
  end

  def complete_cac_proofing_steps_before_find_usps_step
    complete_cac_proofing_steps_before_welcome_step
    click_on t('doc_auth.buttons.get_started')
  end

  def complete_cac_proofing_steps_before_usps_list_step
    complete_cac_proofing_steps_before_find_usps_step
    click_continue
  end

  def complete_cac_proofing_steps_before_enter_info_step
    complete_cac_proofing_steps_before_usps_list_step
    click_continue
  end

  def complete_cac_proofing_steps_before_verify_step
    complete_cac_proofing_steps_before_enter_info_step
    click_continue
  end

  def complete_cac_proofing_steps_before_encrypt_step
    complete_cac_proofing_steps_before_verify_step
    click_continue
  end

  def complete_cac_proofing_steps_before_bar_code_step
    complete_cac_proofing_steps_before_encrypt_step
    click_continue
  end
end

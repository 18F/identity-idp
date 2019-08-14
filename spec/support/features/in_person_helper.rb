module InPersonHelper
  def idv_in_person_welcome_step
    idv_in_person_step_path(step: :welcome)
  end

  def idv_in_person_find_usps_step
    idv_in_person_step_path(step: :find_usps)
  end

  def idv_in_person_usps_list_step
    idv_in_person_step_path(step: :usps_list)
  end

  def idv_in_person_enter_info_step
    idv_in_person_step_path(step: :enter_info)
  end

  def idv_in_person_verify_step
    idv_in_person_step_path(step: :verify)
  end

  def idv_in_person_encrypt_step
    idv_in_person_step_path(step: :encrypt)
  end

  def idv_in_person_bar_code_step
    idv_in_person_step_path(step: :bar_code)
  end

  def enable_in_person_proofing
    allow(Figaro.env).to receive(:in_person_proofing_enabled).and_return('true')
  end

  def complete_in_person_steps_before_welcome_step
    visit idv_in_person_welcome_step
  end

  def complete_in_person_steps_before_find_usps_step
    complete_in_person_steps_before_welcome_step
    click_on t('in_person_proofing.buttons.get_started')
  end

  def complete_in_person_steps_before_usps_list_step
    complete_in_person_steps_before_find_usps_step
    click_continue
  end

  def complete_in_person_steps_before_enter_info_step
    complete_in_person_steps_before_usps_list_step
    click_continue
  end

  def complete_in_person_steps_before_verify_step
    complete_in_person_steps_before_enter_info_step
    click_continue
  end

  def complete_in_person_steps_before_encrypt_step
    complete_in_person_steps_before_verify_step
    click_continue
  end

  def complete_in_person_steps_before_bar_code_step
    complete_in_person_steps_before_encrypt_step
    click_continue
  end
end

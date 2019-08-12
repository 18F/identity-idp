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

  def idv_cac_proofing_success_step
    idv_cac_step_path(step: :success)
  end

  def enable_cac_proofing
    allow(Figaro.env).to receive(:cac_proofing_enabled).and_return('true')
  end

  def complete_cac_proofing_steps_before_welcome_step
    visit idv_cac_proofing_welcome_step
  end

  def complete_cac_proofing_steps_before_present_cac_step
    complete_cac_proofing_steps_before_welcome_step
    click_on t('cac_proofing.buttons.get_started')
  end

  def complete_cac_proofing_steps_before_enter_info_step
    complete_cac_proofing_steps_before_present_cac_step
    click_link t('forms.buttons.cac')
    visit idv_cac_step_path(step: :present_cac, token: 'foo')
  end

  def complete_cac_proofing_steps_before_verify_step
    complete_cac_proofing_steps_before_enter_info_step
    fill_out_cac_proofing_form_ok
    click_continue
  end

  def complete_cac_proofing_steps_before_success_step
    complete_cac_proofing_steps_before_verify_step
    click_continue
  end

  def fill_out_cac_proofing_form_ok
    fill_in 'doc_auth[address1]', with: '123 Main St'
    fill_in 'doc_auth[city]', with: 'Nowhere'
    select 'Virginia', from: 'doc_auth[state]'
    fill_in 'doc_auth[zipcode]', with: '66044'
    fill_in 'doc_auth[dob]', with: '01/02/1980'
    fill_in 'doc_auth[ssn]', with: '666-66-1234'
  end
end

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
    Rails.application.reload_routes!
  end

  def complete_in_person_steps_before_welcome_step
    visit idv_in_person_welcome_step
  end

  def complete_in_person_steps_before_find_usps_step
    complete_in_person_steps_before_welcome_step
    click_on t('doc_auth.buttons.get_started')
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

  def fill_out_personal_info_form_ok
    fill_in 'in_person_first_name', with: 'José'
    fill_in 'in_person_last_name', with: 'One'
    fill_in 'in_person_address1', with: '123 Main St'
    fill_in 'in_person_city', with: 'Nowhere'
    select 'Virginia', from: 'in_person_state'
    fill_in 'in_person_zipcode', with: '66044'
    fill_in 'in_person_dob', with: '01/02/1980'
    fill_in 'in_person_ssn', with: '666-66-1234'
    find("label[for='in_person_state_id_type_drivers_permit']").click
    fill_in 'in_person_state_id_number', with: '123456789'
  end
end

module IdvHelper
  def max_attempts_less_one
    Idv::Attempter.idv_max_attempts - 1
  end

  def user_password
    Features::SessionHelper::VALID_PASSWORD
  end

  def fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'José'
    fill_in 'profile_last_name', with: 'One'
    fill_in 'profile_ssn', with: '666-66-1234'
    fill_in 'profile_dob', with: '01/02/1980'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Kansas', from: 'profile_state'
    fill_in 'profile_zipcode', with: '66044'
  end

  def fill_out_idv_form_fail
    fill_in 'profile_first_name', with: 'Bad'
    fill_in 'profile_last_name', with: 'User'
    fill_in 'profile_ssn', with: '666-66-6666'
    fill_in 'profile_dob', with: '01/02/1900'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Kansas', from: 'profile_state'
    fill_in 'profile_zipcode', with: '00000'
  end

  def fill_out_idv_previous_address_ok
    fill_in 'profile_prev_address1', with: '456 Other Ave'
    fill_in 'profile_prev_city', with: 'Elsewhere'
    select 'Missouri', from: 'profile_prev_state'
    fill_in 'profile_prev_zipcode', with: '12345'
  end

  def fill_out_idv_previous_address_fail
    fill_in 'profile_prev_address1', with: '456 Other Ave'
    fill_in 'profile_prev_city', with: 'Elsewhere'
    select 'Missouri', from: 'profile_prev_state'
    fill_in 'profile_prev_zipcode', with: '00000'
  end

  def fill_out_financial_form_ok
    fill_in :idv_finance_form_ccn, with: '12345678'
  end

  def fill_out_financial_form_fail
    fill_in :idv_finance_form_ccn, with: '00000000'
  end

  def fill_out_phone_form_ok(phone = '415-555-0199')
    fill_in :idv_phone_form_phone, with: phone
  end

  def fill_out_phone_form_fail
    fill_in :idv_phone_form_phone, with: '(555) 555-5555'
  end

  def click_idv_begin
    click_on t('idv.index.continue_link')
  end

  def click_idv_continue
    click_button t('forms.buttons.continue')
  end

  def click_idv_address_choose_phone
    click_link t('idv.buttons.activate_by_phone')
  end

  def click_idv_address_choose_usps
    click_link t('idv.buttons.activate_by_mail')
  end

  def click_idv_cancel_modal
    within('.modal') do
      click_on t('idv.buttons.cancel')
    end
  end

  def click_idv_cancel
    click_on t('idv.buttons.cancel')
  end

  def complete_idv_profile_ok(user)
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue
    click_idv_address_choose_phone
    fill_out_phone_form_ok(user.phone)
    click_idv_continue
    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_submit_default
  end
end

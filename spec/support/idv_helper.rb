module IdvHelper
  def fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'Some'
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
    fill_in 'profile_zipcode', with: '66044'
  end

  def fill_out_financial_form_ok
    fill_in :idv_finance_form_ccn, with: '12345678'
  end

  def fill_out_phone_form_ok(phone = '415-555-0199')
    fill_in :idv_phone_form_phone, with: phone
  end

  def fill_out_phone_form_fail
    fill_in :idv_phone_form_phone, with: '(555) 555-5555'
  end

  def click_idv_continue
    click_button t('forms.buttons.continue')
  end

  def complete_idv_profile_ok(user)
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue
    fill_out_phone_form_ok(user.phone)
    click_idv_continue
    fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
    click_submit_default
  end

  def click_acknowledge_recovery_code
    click_button t('forms.buttons.continue')
  end

  def stub_idv_session
    stub_sign_in(user)
    idv_session = Idv::Session.new(subject.user_session, user)
    idv_session.vendor = :mock
    idv_session.applicant = applicant
    idv_session.resolution = resolution
    idv_session.profile_id = profile.id
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end
end

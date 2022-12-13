shared_examples 'failed idv phone job' do
  let(:locale) { LinkLocaleResolver.locale }

  before do
    visit_idp_from_sp_with_ial2(:oidc)
    complete_idv_steps_before_step(:phone)
  end

  context 'the proofer raises an error' do
    before do
      fill_out_phone_form_error
      click_idv_send_security_code
    end

    it 'renders a jobfail failure screen' do
      expect(page).to have_current_path(phone_jobfail_path)
      expect(page).to have_content t('idv.failure.phone.heading')
      expect(page).to have_content t('idv.failure.phone.jobfail')
    end
  end

  context 'the proofer times out' do
    before do
      fill_out_phone_form_timeout
      click_idv_send_security_code
    end

    it 'renders a timeout failure screen' do
      expect(page).to have_current_path(phone_timeout_path)
      expect(page).to have_content t('idv.failure.phone.heading')
      expect(page).to have_content t('idv.failure.phone.timeout')
    end
  end

  def fill_out_idv_form_error
    fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'Fail'
  end

  def fill_out_phone_form_error
    fill_in :idv_phone_form_phone,
            with:
                  Proofing::Mock::AddressMockClient::FAILED_TO_CONTACT_PHONE_NUMBER
  end

  def fill_out_idv_form_timeout
    fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'Time'
  end

  def fill_out_phone_form_timeout
    fill_in :idv_phone_form_phone,
            with:
                  Proofing::Mock::AddressMockClient::PROOFER_TIMEOUT_PHONE_NUMBER
  end

  def session_timeout_path
    idv_session_errors_timeout_path(locale: locale)
  end

  def phone_timeout_path
    idv_phone_errors_timeout_path(locale: locale)
  end

  def session_jobfail_path
    idv_session_errors_jobfail_path(locale: locale)
  end

  def phone_jobfail_path
    idv_phone_errors_jobfail_path(locale: locale)
  end
end

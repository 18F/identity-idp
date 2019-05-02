shared_examples 'failed idv job' do |step|
  let(:locale) { LinkLocaleResolver.locale }
  let(:step_locale_key) do
    return :sessions if step == :profile
    step
  end

  before do
    visit_idp_from_sp_with_loa3(:oidc)
    complete_idv_steps_before_step(step)
  end

  context 'the proofer raises an error' do
    before do
      fill_out_idv_form_error if step == :profile
      fill_out_phone_form_error if step == :phone
      click_idv_continue
    end

    it 'renders a jobfail failure screen' do
      expect(page).to have_current_path(session_failure_path(:jobfail)) if step == :profile
      expect(page).to have_current_path(phone_failure_path(:jobfail)) if step == :phone
      expect(page).to have_content t("idv.failure.#{step_locale_key}.heading")
      expect(page).to have_content t("idv.failure.#{step_locale_key}.jobfail")
    end
  end

  context 'the proofer times out' do
    before do
      fill_out_idv_form_timeout if step == :profile
      fill_out_phone_form_timeout if step == :phone
      click_idv_continue
    end

    it 'renders a timeout failure screen' do
      expect(page).to have_current_path(session_failure_path(:timeout)) if step == :profile
      expect(page).to have_current_path(phone_failure_path(:timeout)) if step == :phone
      expect(page).to have_content t("idv.failure.#{step_locale_key}.heading")
      expect(page).to have_content t("idv.failure.#{step_locale_key}.timeout")
    end
  end

  def fill_out_idv_form_error
    fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'Fail'
  end

  def fill_out_phone_form_error
    fill_in :idv_phone_form_phone, with: '7035555999'
  end

  def fill_out_idv_form_timeout
    fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'Time'
  end

  def fill_out_phone_form_timeout
    fill_in :idv_phone_form_phone, with: '7035555888'
  end

  def session_failure_path(reason)
    idv_session_failure_path(reason, locale: locale)
  end

  def phone_failure_path(reason)
    idv_phone_failure_path(reason, locale: locale)
  end
end

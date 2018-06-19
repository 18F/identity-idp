shared_examples 'fail to verify idv info' do |step|
  let(:locale) { LinkLocaleResolver.locale }
  let(:step_locale_key) do
    return :sessions if step == :profile
    step
  end

  shared_examples 'warning failure' do
    it 'renders a warning failure screen and lets the user try again' do
      expect(page).to have_current_path(idv_session_failure_path(:warning, locale: locale)) if step == :profile
      expect(page).to have_current_path(idv_phone_failure_path(:warning, locale: locale)) if step == :phone
      expect(page).to have_content t("idv.modal.#{step_locale_key}.heading")
      expect(page).to have_content t("idv.modal.#{step_locale_key}.warning")

      click_on t('idv.modal.button.warning')

      if step == :profile
        fill_out_idv_form_ok
        click_idv_continue
      end
      fill_out_phone_form_ok if step == :phone
      click_idv_continue

      expect(page).to have_current_path(idv_phone_path) if step == :profile
      expect(page).to have_current_path(idv_otp_delivery_method_path) if step == :phone
      expect(page).to have_content(t('idv.titles.session.phone')) if step == :profile
      expect(page).to have_content(t('idv.titles.otp_delivery_method')) if step == :phone
    end
  end

  before do
    start_idv_from_sp
    complete_idv_steps_before_step(step)
    fill_out_idv_form_fail if step == :profile
    fill_out_phone_form_fail if step == :phone
    click_continue
  end

  context 'without js' do
    it_behaves_like 'warning failure'
  end

  context 'with js', :js do
    it_behaves_like 'warning failure'
  end
end

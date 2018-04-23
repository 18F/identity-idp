shared_examples 'fail to verify idv info' do |step|
  let(:step_locale_key) do
    return :sessions if step == :profile
    step
  end

  before do
    start_idv_from_sp
    complete_idv_steps_before_step(step)
    fill_out_idv_form_fail if step == :profile
    fill_out_phone_form_fail if step == :phone
    click_continue
  end

  context 'without js' do
    it 'renders a flash message and lets the user try again' do
      expect_page_to_have_warning_message
      expect(page).to have_current_path(verify_session_result_path) if step == :profile
      expect(page).to have_current_path(verify_phone_result_path) if step == :phone

      fill_out_idv_form_ok if step == :profile
      fill_out_phone_form_ok if step == :phone
      click_idv_continue

      expect(page).to have_content(t('idv.titles.select_verification')) if step == :profile
      expect(page).to have_current_path(verify_address_path) if step == :profile
      expect(page).to have_content(t('idv.titles.otp_delivery_method')) if step == :phone
      expect(page).to have_current_path(verify_otp_delivery_method_path) if step == :phone
    end
  end

  context 'with js', :js do
    it 'renders a modal and lets the user try again' do
      expect_page_to_have_warning_modal
      expect(page).to have_current_path(verify_session_result_path) if step == :profile
      expect(page).to have_current_path(verify_phone_result_path) if step == :phone

      dismiss_warning_modal
      fill_out_idv_form_ok if step == :profile
      fill_out_phone_form_ok if step == :phone
      click_idv_continue

      expect(page).to have_content(t('idv.titles.select_verification')) if step == :profile
      expect(page).to have_current_path(verify_address_path) if step == :profile
      expect(page).to have_content(t('idv.titles.otp_delivery_method')) if step == :phone
      expect(page).to have_current_path(verify_otp_delivery_method_path) if step == :phone
    end
  end

  def expect_page_to_have_warning_message
    expect(page).to have_content t("idv.modal.#{step_locale_key}.heading")
    expect(page).to have_content t("idv.modal.#{step_locale_key}.warning")
  end

  def expect_page_to_have_warning_modal
    expect(page).to have_css('.modal-warning', text: t("idv.modal.#{step_locale_key}.heading"))
    expect(page).to have_css(
      '.modal-warning',
      text: strip_tags(t("idv.modal.#{step_locale_key}.warning"))
    )
  end

  def dismiss_warning_modal
    click_button t('idv.modal.button.warning')
  end
end

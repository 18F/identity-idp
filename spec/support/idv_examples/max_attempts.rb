shared_examples 'verification step max attempts' do |step|
  scenario 'more than 3 attempts in 24 hours prevents further attempts' do
    visit_idp_from_sp_with_loa3(:oidc)

    if step == :phone
      click_idv_begin
      click_idv_address_choose_phone
    end

    expect(page).to have_content(
      t('idv.messages.hardfail', hours: Figaro.env.idv_attempt_window_in_hours)
    )
    expect(current_url).to eq(verify_fail_url)
  end

  scenario 'user sees failure flash message' do
    expect(page).to have_css('.alert-error', text: t("idv.modal.#{step}.heading"))
    expect(page).to have_css(
      '.alert-error',
      text: ActionController::Base.helpers.strip_tags(t("idv.modal.#{step}.fail"))
    )
  end

  context 'with js', :js do
    scenario 'user sees the failure modal' do
      expect(page).to have_css('.modal-fail', text: t("idv.modal.#{step}.heading"))
      expect(page).to have_css(
        '.modal-fail',
        text: ActionController::Base.helpers.strip_tags(t("idv.modal.#{step}.fail"))
      )
    end
  end
end

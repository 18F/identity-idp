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

    user.reload

    expect(user.idv_attempted_at).to_not be_nil
  end

  scenario 'after 24 hours the user can retry and complete idv' do
    visit account_path
    first(:link, t('links.sign_out')).click
    reattempt_interval = (Figaro.env.idv_attempt_window_in_hours.to_i + 1).hours

    Timecop.travel reattempt_interval do
      visit_idp_from_sp_with_loa3(:oidc)
      click_link t('links.sign_in')
      sign_in_live_with_2fa(user)

      expect(page).to_not have_content(t("idv.modal.#{step}.heading"))
      expect(current_url).to eq(verify_url)

      click_idv_begin
      complete_idv_profile_ok(user)
      click_acknowledge_personal_key
      click_idv_continue

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end
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

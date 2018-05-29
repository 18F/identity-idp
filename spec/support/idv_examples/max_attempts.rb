shared_examples 'verification step max attempts' do |step, sp|
  let(:user) { user_with_2fa }
  let(:step_locale_key) do
    return :sessions if step == :profile
    step
  end

  before do
    start_idv_from_sp(sp)
    complete_idv_steps_before_step(step, user)
    if step == :profile
      perfom_maximum_allowed_idv_step_attempts { fill_out_idv_form_fail }
    elsif step == :phone
      perfom_maximum_allowed_idv_step_attempts { fill_out_phone_form_fail }
    end
  end

  scenario 'more than 3 attempts in 24 hours prevents further attempts' do
    # Blocked if visiting verify directly
    visit idv_url
    advance_to_phone_step if step == :phone
    expect_user_to_be_unable_to_perform_idv(sp)

    # Blocked if visiting from an SP
    visit_idp_from_sp_with_loa3(:oidc)
    advance_to_phone_step if step == :phone
    expect_user_to_be_unable_to_perform_idv(sp)

    if step == :sessions
      user.reload

      expect(user.idv_attempted_at).to_not be_nil
    end
  end

  scenario 'after 24 hours the user can retry and complete idv' do
    visit account_path
    first(:link, t('links.sign_out')).click
    reattempt_interval = (Figaro.env.idv_attempt_window_in_hours.to_i + 1).hours

    Timecop.travel reattempt_interval do
      visit_idp_from_sp_with_loa3(:oidc)
      click_link t('links.sign_in')
      sign_in_live_with_2fa(user)

      expect(page).to_not have_content(t("idv.modal.#{step_locale_key}.heading"))
      expect(current_url).to eq(idv_jurisdiction_url)

      fill_out_idv_jurisdiction_ok
      click_idv_continue
      complete_idv_profile_ok(user)
      click_acknowledge_personal_key
      click_idv_continue

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end
  end

  scenario 'user sees failure flash message' do
    expect(page).to have_css('.alert-error', text: t("idv.modal.#{step_locale_key}.heading"))
    expect(page).to have_css(
      '.alert-error',
      text: strip_tags(t("idv.modal.#{step_locale_key}.fail"))
    )
  end

  context 'with js', :js do
    scenario 'user sees the failure modal' do
      expect(page).to have_css('.modal-fail', text: t("idv.modal.#{step_locale_key}.heading"))
      expect(page).to have_css(
        '.modal-fail',
        text: strip_tags(t("idv.modal.#{step_locale_key}.fail"))
      )
    end
  end

  def perfom_maximum_allowed_idv_step_attempts
    max_attempts_less_one.times do
      yield
      click_idv_continue
      click_button t('idv.modal.button.warning') if javascript_enabled?
    end
    yield
    click_idv_continue
  end

  def expect_user_to_be_unable_to_perform_idv(sp)
    expect(page).to have_content(t('idv.titles.hardfail', app: 'login.gov'))
    if sp.present?
      expect(page).to have_content(
        t('idv.messages.hardfail', hours: Figaro.env.idv_attempt_window_in_hours)
      )
      expect(page).to have_content(
        strip_tags(t('idv.messages.hardfail4_html', sp: 'Test SP'))
      )
    else
      expect(page).to have_content(
        strip_tags(t('idv.messages.help_center_html'))
      )
    end
    expect(current_url).to eq(idv_fail_url)
  end

  def advance_to_phone_step
    fill_out_idv_jurisdiction_ok
    click_idv_continue
    click_idv_continue
    click_idv_address_choose_phone
  end
end

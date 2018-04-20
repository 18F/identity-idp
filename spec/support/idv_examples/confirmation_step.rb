shared_examples 'idv confirmation step' do |sp|
  context 'after choosing to verify by letter' do
    before do
      start_idv_from_sp(sp)
      complete_idv_steps_with_usps_before_confirmation_step
    end

    it 'redirects to the come back later url then to the sp or account' do
      click_acknowledge_personal_key

      expect(page).to have_current_path(verify_come_back_later_path)
      click_on t('forms.buttons.continue')

      # SAML test SP does not have a return URL, so it does not have a link
      # back to the SP
      if sp == :oidc
        expect(current_url).to start_with('http://localhost:7654/auth/result')
      else
        expect(page).to have_current_path(account_path)
      end
    end
  end

  context 'after choosing to verify by phone' do
    before do
      start_idv_from_sp(sp)
      complete_idv_steps_with_phone_before_confirmation_step
    end

    it 'redirects to the completions page and then to the SP', if: sp.present? do
      click_acknowledge_personal_key

      expect(page).to have_current_path(sign_up_completed_path)

      click_on t('forms.buttons.continue')

      if sp == :oidc
        expect(current_url).to start_with('http://localhost:7654/auth/result')
      else
        expect(current_path).to eq(api_saml_auth_path)
      end
    end

    it 'redirects to the account page', if: sp.nil? do
      click_acknowledge_personal_key

      expect(page).to have_content(t('headings.account.verified_account'))
      expect(page).to have_current_path(account_path)
    end
  end
end

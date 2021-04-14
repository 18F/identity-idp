shared_examples 'idv confirmation step' do |sp|
  context 'after choosing to verify by letter' do
    let(:ial2_step_indicator_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
        and_return(ial2_step_indicator_enabled)
      start_idv_from_sp(sp)
      complete_idv_steps_with_gpo_before_confirmation_step
    end

    it 'redirects to the come back later url then to the sp or account' do
      click_acknowledge_personal_key

      expect(page).to have_current_path(idv_come_back_later_path)
      click_on t('forms.buttons.continue')

      if sp == :oidc
        expect(current_url).to start_with('http://localhost:7654/auth/result')
      elsif sp == :saml
        expect(current_url).to start_with('http://example.com/')
      else
        expect(current_url).to eq(account_url)
      end
    end

    context 'user selected gpo verification' do
      context 'ial2 step indicator enabled' do
        it 'shows step indicator progress with pending verify step' do
          expect(page).to have_css(
            '.step-indicator__step--current',
            text: t('step_indicator.flows.idv.secure_account'),
          )
          expect(page).to have_css(
            '.step-indicator__step--pending',
            text: t('step_indicator.flows.idv.verify_phone_or_address'),
          )
        end
      end

      context 'ial2 step indicator disabled' do
        let(:ial2_step_indicator_enabled) { false }

        it 'does not show step indicator progress' do
          expect(page).not_to have_css('.step-indicator')
        end
      end
    end
  end

  context 'after choosing to verify by phone' do
    let(:ial2_step_indicator_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
        and_return(ial2_step_indicator_enabled)
      start_idv_from_sp(sp)
      complete_idv_steps_with_phone_before_confirmation_step
    end

    it 'shows step indicator progress' do
    end

    it 'redirects to the completions page and then to the SP', if: sp.present? do
      click_acknowledge_personal_key

      expect(page).to have_current_path(sign_up_completed_path)

      click_agree_and_continue

      if sp == :oidc
        expect(current_url).to start_with('http://localhost:7654/auth/result')
      else
        expect(current_path).to eq(api_saml_auth2021_path)
      end
    end

    it 'redirects to the account page', if: sp.nil? do
      click_acknowledge_personal_key

      expect(page).to have_content(t('headings.account.verified_account'))
      expect(page).to have_current_path(account_path)
    end

    context 'user selected gpo verification' do
      context 'ial2 step indicator enabled' do
        it 'shows step indicator progress without pending verify step' do
          expect(page).to have_css(
            '.step-indicator__step--current',
            text: t('step_indicator.flows.idv.secure_account'),
          )
          expect(page).not_to have_css('.step-indicator__step--pending')
        end
      end

      context 'ial2 step indicator disabled' do
        let(:ial2_step_indicator_enabled) { false }

        it 'does not show step indicator progress' do
          expect(page).not_to have_css('.step-indicator')
        end
      end
    end
  end
end

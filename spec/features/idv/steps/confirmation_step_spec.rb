require 'rails_helper'

feature 'idv confirmation step', js: true do
  include IdvStepHelper

  let(:idv_api_enabled_steps) { [] }
  let(:idv_personal_key_confirmation_enabled) { true }
  let(:sp) { nil }
  let(:address_verification_mechanism) { :phone }

  before do
    allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(idv_api_enabled_steps)
    allow(IdentityConfig.store).to receive(:idv_personal_key_confirmation_enabled).
      and_return(idv_personal_key_confirmation_enabled)
    start_idv_from_sp(sp)
    complete_idv_steps_before_confirmation_step(address_verification_mechanism)
  end

  it_behaves_like 'personal key page'

  it 'shows status content for phone verification progress' do
    expect(page).to have_content(t('idv.messages.confirm'))
    expect(page).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.secure_account'),
    )
    expect(page).to have_css(
      '.step-indicator__step--complete',
      text: t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    expect(page).not_to have_css('.step-indicator__step--pending')
  end

  it 'allows the user to refresh and still displays the personal key' do
    # Visit the current path is the same as refreshing
    visit current_path
    expect(page).to have_content(t('headings.personal_key'))
  end

  context 'with idv app feature enabled' do
    let(:idv_api_enabled_steps) { ['password_confirm', 'personal_key', 'personal_key_confirm'] }

    it_behaves_like 'personal key page'

    it 'allows the user to refresh and still displays the personal key' do
      # Visit the current path is the same as refreshing
      visit current_path
      expect(page).to have_content(t('headings.personal_key'))

      acknowledge_and_confirm_personal_key
      expect(page).to have_current_path(account_path)
    end

    context 'with personal key confirmation disabled' do
      let(:idv_personal_key_confirmation_enabled) { false }

      before do
        click_continue if javascript_enabled?
      end

      it 'does not display modal content. and continues to the account page' do
        expect(page).not_to have_content t('forms.personal_key.title')
        expect(page).not_to have_content t('forms.personal_key.instructions')
        expect(current_path).to eq(account_path)
        expect(page).to have_content t('headings.account.verified_account')
      end
    end
  end

  context 'verifying by gpo' do
    let(:address_verification_mechanism) { :gpo }

    it 'shows status content for gpo verification progress' do
      expect(page).to have_content(t('idv.messages.mail_sent'))
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.secure_account'),
      )
      expect(page).to have_css(
        '.step-indicator__step--pending',
        text: t('step_indicator.flows.idv.verify_phone_or_address'),
      )
    end

    it_behaves_like 'personal key page', :gpo
  end

  context 'with associated sp' do
    let(:sp) { :oidc }

    it 'redirects to the completions page and then to the SP' do
      acknowledge_and_confirm_personal_key

      expect(page).to have_current_path(sign_up_completed_path)

      click_agree_and_continue

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end

    context 'with personal key confirmation disabled' do
      let(:idv_personal_key_confirmation_enabled) { false }

      it 'redirects to the completions page and then to the SP' do
        click_acknowledge_personal_key

        expect(page).to have_current_path(sign_up_completed_path)

        click_agree_and_continue

        expect(current_url).to start_with('http://localhost:7654/auth/result')
      end
    end
  end
end

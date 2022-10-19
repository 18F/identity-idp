require 'rails_helper'

feature 'idv confirmation step', js: true do
  include IdvStepHelper

  let(:sp) { nil }
  let(:address_verification_mechanism) { :phone }

  before do
    start_idv_from_sp(sp)
    complete_idv_steps_before_confirmation_step(address_verification_mechanism)
  end

  it 'shows status content for phone verification progress' do
    expect(page).to have_content(t('idv.messages.confirm'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
    expect(page).to have_css(
      '.step-indicator__step--complete',
      text: t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    expect(page).not_to have_content(t('step_indicator.flows.idv.get_a_letter'))
  end

  it 'allows the user to refresh and still displays the personal key' do
    # Visit the current path is the same as refreshing
    visit current_path
    expect(page).to have_content(t('forms.personal_key_partial.acknowledgement.header'))
  end

  context 'verifying by gpo' do
    let(:address_verification_mechanism) { :gpo }

    it 'shows status content for gpo verification progress' do
      expect(page).to have_content(t('idv.messages.mail_sent'))
      expect_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
      expect(page).to have_content(t('step_indicator.flows.idv.get_a_letter'))
      expect(page).not_to have_content(t('step_indicator.flows.idv.verify_phone_or_address'))
    end
  end

  context 'with associated sp' do
    let(:sp) { :oidc }

    it "forces the user to click the 'acknowledge' checkbox before proceeding" do
      click_continue

      expect(page).to have_content(t('forms.validation.required_checkbox'))
      expect(current_path).to eq(idv_personal_key_path)

      acknowledge_and_confirm_personal_key
      expect(page).to have_current_path(sign_up_completed_path)
    end

    it 'redirects to the completions page and then to the SP' do
      acknowledge_and_confirm_personal_key

      expect(page).to have_current_path(sign_up_completed_path)

      click_agree_and_continue

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end
  end
end

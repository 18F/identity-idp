require 'rails_helper'

RSpec.describe 'proofing components' do
  include DocAuthHelper
  include IdvHelper
  include SamlAuthHelper

  describe 'proofing jobs' do
    let(:email) { 'test@test.com' }
    let(:user) { User.find_with_email(email) }

    before do
      allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).
        and_return(ruby_workers_idv_enabled)
      allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls).
        and_return(doc_auth_enable_presigned_s3_urls)

      visit_idp_from_sp_with_ial2(:oidc)
      register_user(email)

      expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)

      complete_all_doc_auth_steps
      click_idv_continue
      fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
      click_continue
      acknowledge_and_confirm_personal_key
    end

    context 'async proofing', js: true do
      let(:ruby_workers_idv_enabled) { true }
      let(:doc_auth_enable_presigned_s3_urls) { true }

      it 'records proofing components' do
        proofing_components = user.active_profile.proofing_components
        expect(proofing_components['document_check']).to eq('mock')
        expect(proofing_components['document_type']).to eq('state_id')
      end
    end

    context 'sync proofing', js: true do
      let(:ruby_workers_idv_enabled) { false }
      let(:doc_auth_enable_presigned_s3_urls) { false }

      it 'records proofing components' do
        proofing_components = user.active_profile.proofing_components
        expect(proofing_components['document_check']).to eq('mock')
        expect(proofing_components['document_type']).to eq('state_id')
      end
    end
  end

  it 'clears liveness enabled proofing component when user re-proofs without liveness', js: true do
    allow(IdentityConfig.store).to receive(:liveness_checking_enabled).and_return(true)
    user = user_with_2fa
    sign_in_and_2fa_user(user)
    visit_idp_from_oidc_sp_with_ial2_strict
    complete_proofing_steps

    expect(user.active_profile.includes_liveness_check?).to be_truthy

    visit account_path
    first(:link, t('links.sign_out')).click

    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(user.reload.profiles.where(active: true)).to be_empty

    visit_idp_from_oidc_sp_with_ial2
    click_on t('links.account.reactivate.without_key')
    click_on t('forms.buttons.continue')

    complete_proofing_steps

    user = User.find(user.id)
    expect(user.active_profile.includes_liveness_check?).to be_falsy
  end
end

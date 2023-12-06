require 'rails_helper'

RSpec.feature 'how to verify step' do
  include IdvHelper
  include DocAuthHelper

  context 'when ipp is enabled and opt-in ipp is disabled' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
      complete_agreement_step
    end

    it 'skips when disabled and redirects to hybird handoff)' do
      expect(page).to have_current_path(idv_hybrid_handoff_url)
    end
  end

  context 'when ipp is disabled and opt-in ipp is enabled' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { false }
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
      complete_agreement_step
    end

    it 'skips when disabled and redirects to hybird handoff' do
      expect(page).to have_current_path(idv_hybrid_handoff_url)
    end
  end

  context 'when both ipp and opt-in ipp are disabled' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { false }
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
      complete_agreement_step
    end

    it 'skips when disabled and redirects to hybird handoff' do
      expect(page).to have_current_path(idv_hybrid_handoff_url)
    end
  end

  context 'when both ipp and opt-in ipp are enabled' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
      complete_agreement_step
    end

    it 'displays expected content and requires a choice' do
      expect(page).to have_current_path(idv_how_to_verify_path)

      # Try to continue without an option
      click_continue

      expect(page).to have_current_path(idv_how_to_verify_path)
      expect(page).to have_content(t('errors.doc_auth.how_to_verify_form'))

      complete_how_to_verify_step
      expect(page).to have_current_path(idv_hybrid_handoff_url)
    end
  end
end

require 'rails_helper'

RSpec.feature 'how to verify step', js: true do
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

  describe 'navigating to How To Verify from Agreement page in 50/50 state' do
    context "opt in false at start but true during navigation" do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        page.refresh
      end
      
      it 'should be not be bounced back from hybrid handoff to how to verify' do
        expect(page).not_to have_current_path(idv_how_to_verify_url)
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end

    context "opt in true at start but false during navigation" do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        expect(page).to have_current_path(idv_how_to_verify_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        page.refresh
      end
      
      it 'should be on the hybrid handoff page' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end

  describe 'navigating backwards from How to Verify page in 50/50 state' do
    context 'Going back from Hybrid Handoff with opt in disabled in transit' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        complete_how_to_verify_step
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        page.go_back
      end
      
      it 'should be not be bounced back to how to verify' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
    context "Going back from Hybrid Handoff with opt in enabled in transit" do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        page.go_back
      end
      
      it 'should be not be bounced back to how to verify' do
        expect(page).to have_current_path(idv_agreement_url)
      end
    end
    context "Going back from Hybrid Handoff with opt in enabled the whole time" do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        complete_how_to_verify_step
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        page.go_back
      end
      
      it 'should be bounced back to how to verify' do
        expect(page).to have_current_path(idv_how_to_verify_url)
      end
    end
    context "Going back from Hybrid Handoff with opt in disabled the whole time" do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        page.go_back
      end
      
      it 'should be not be bounced back to how to verify' do
        expect(page).to have_current_path(idv_agreement_url)
      end
    end
  end
end

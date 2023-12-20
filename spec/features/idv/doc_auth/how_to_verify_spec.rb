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

    it 'skips when disabled and redirects to hybrid handoff' do
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
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
    end

    context 'opt in false at start but true during navigation' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
      end

      it 'should not be bounced back from Hybrid Handoff to How to Verify' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        page.refresh
        expect(page).not_to have_current_path(idv_how_to_verify_url)
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end

    context 'opt in true at start but false during navigation' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
      end

      it 'should be redirected to Hybrid Handoff page when opt in is false' do
        expect(page).to have_current_path(idv_how_to_verify_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        page.refresh
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end

  describe 'navigating backwards from How to Verify page in 50/50 state' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
    end

    context 'Going back from Hybrid Handoff with opt in disabled midstream' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        complete_how_to_verify_step
      end

      it 'should not be bounced back to How to Verify with opt in disabled midstream' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        page.go_back
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        page.go_back
        expect(page).to have_current_path(idv_agreement_url)
      end
    end

    context 'Going back from Hybrid Handoff with opt in enabled midstream' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
      end

      it 'should go back to the Agreement step from Hybrid Handoff with opt in toggled midstream' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        page.go_back
        expect(page).to have_current_path(idv_agreement_url)
      end
    end

    context 'Going back from Hybrid Handoff with opt in enabled the whole time' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        complete_how_to_verify_step
      end

      it 'should be bounced back to How to Verify' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        page.go_back
        expect(page).to have_current_path(idv_how_to_verify_url)
      end
    end

    context 'Going back from Hybrid Handoff with opt in disabled the whole time' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
      end

      it 'should be not be bounced back to How to Verify' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        page.go_back
        expect(page).to have_current_path(idv_agreement_url)
      end
    end
  end

  describe 'navigating backwards from Document Capture page in 50/50 state' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
    end

    context 'Going back from Document Capture with opt in disabled midstream' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        complete_how_to_verify_step(remote: false)
      end

      it 'should not be bounced back to How to Verify with opt in disabled midstream' do
        expect(page).to have_current_path(idv_document_capture_path)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        page.go_back
        expect(page).to have_current_path(idv_document_capture_path)
        page.go_back
        expect(page).to have_current_path(idv_agreement_url)
      end
    end

    context 'Going back from Document Capture with opt in enabled midstream' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        complete_doc_auth_steps_before_document_capture_step
      end

      it 'should go to Hybrid Handoff from Document Capture with opt in toggled midstream' do
        expect(page).to have_current_path(idv_document_capture_path)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        page.go_back
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end

    context 'Going back from Document Capture with opt in enabled the whole time' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        complete_how_to_verify_step(remote: false)
      end

      it 'should be bounced back to How to Verify' do
        expect(page).to have_current_path(idv_document_capture_path)
        page.go_back
        expect(page).to have_current_path(idv_how_to_verify_url)
      end
    end

    context 'Going back from Document Capture with opt in disabled the whole time' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_agreement_step
        complete_agreement_step
        complete_doc_auth_steps_before_document_capture_step
      end

      it 'should be not be bounced back to how to verify' do
        expect(page).to have_current_path(idv_document_capture_path)
        page.go_back
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end
end

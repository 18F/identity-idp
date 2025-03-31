require 'rails_helper'

RSpec.feature 'how to verify step', js: true do
  include IdvHelper
  include DocAuthHelper

  let(:user) { user_with_2fa }
  let(:ipp_service_provider) { create(:service_provider, :active, :in_person_proofing_enabled) }

  let(:in_person_proofing_enabled) { true }
  let(:in_person_proofing_opt_in_enabled) { false }
  let(:service_provider_in_person_proofing_enabled) { true }
  let(:facial_match_required) { false }
  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) {
      in_person_proofing_enabled
    }
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) {
      in_person_proofing_opt_in_enabled
    }
    allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled)
      .and_return(service_provider_in_person_proofing_enabled)
    visit_idp_from_sp_with_ial2(
      :oidc, **{ client_id: ipp_service_provider.issuer,
                 facial_match_required: facial_match_required }
    )
    sign_in_via_branded_page(user)
    expect(page).to have_current_path(idv_welcome_path)
    complete_doc_auth_steps_before_agreement_step
    complete_agreement_step
  end

  context 'when ipp is enabled and opt-in ipp is disabled' do
    context 'and when sp has opted into ipp' do
      it 'skips when disabled and redirects to hybrid handoff' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end

    context 'and when sp has not opted into ipp' do
      let(:service_provider_in_person_proofing_enabled) { false }

      it 'skips when disabled and redirects to hybrid handoff' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end

  context 'when ipp is disabled and opt-in ipp is enabled' do
    context 'and when sp has opted into ipp' do
      let(:in_person_proofing_enabled) { false }
      let(:in_person_proofing_opt_in_enabled) { true }

      it 'skips when disabled and redirects to hybrid handoff' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end

    context 'and when sp has not opted into ipp' do
      let(:in_person_proofing_enabled) { false }
      let(:in_person_proofing_opt_in_enabled) { true }
      let(:service_provider_in_person_proofing_enabled) { false }

      it 'skips when disabled and redirects to hybrid handoff' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end

  context 'when both ipp and opt-in ipp are disabled' do
    context 'and when sp has opted into ipp' do
      let(:in_person_proofing_enabled) { false }

      it 'skips when disabled and redirects to hybrid handoff' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end

    context 'and when sp has not opted into ipp' do
      let(:in_person_proofing_enabled) { false }
      let(:service_provider_in_person_proofing_enabled) { false }

      it 'skips when disabled and redirects to hybrid handoff' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end

  context 'when both ipp and opt-in ipp are enabled' do
    context 'and when sp has opted into ipp' do
      include InPersonHelper

      let(:in_person_proofing_opt_in_enabled) { true }

      it 'displays expected content and navigates to choice' do
        expect(page).to have_current_path(idv_how_to_verify_path)

        # Choose remote option
        click_on t('forms.buttons.continue_remote')
        expect(page).to have_current_path(idv_hybrid_handoff_url)

        # go back and choose in person option
        page.go_back
        click_on t('forms.buttons.continue_ipp')
        expect(page).to have_current_path(idv_document_capture_path(step: :how_to_verify))
      end

      context 'when selfie is enabled' do
        let(:facial_match_required) { true }

        it 'goes to direct IPP if selected and can come back' do
          expect(page).to have_current_path(idv_how_to_verify_path)
          expect(page).to have_content(t('doc_auth.headings.how_to_verify'))
          click_on t('forms.buttons.continue_ipp')
          expect(page).to have_current_path(idv_document_capture_path(step: :how_to_verify))
          expect_in_person_step_indicator_current_step(
            t('step_indicator.flows.idv.find_a_post_office'),
          )
          expect(page).to have_content(t('headings.verify'))
          click_on t('forms.buttons.back')
          expect(page).to have_current_path(idv_how_to_verify_path)
        end

        context 'when the user is bucketed for Socure doc_auth' do
          before do
            allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return('socure')
            allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return('socure')
          end

          it 'goes to direct IPP if selected and can come back' do
            expect(page).to have_current_path(idv_how_to_verify_path)
            expect(page).to have_content(t('doc_auth.headings.how_to_verify'))
            click_on t('forms.buttons.continue_ipp')
            expect(page).to have_current_path(idv_document_capture_path(step: :how_to_verify))
            expect_in_person_step_indicator_current_step(
              t('step_indicator.flows.idv.find_a_post_office'),
            )
            expect(page).to have_content(t('headings.verify'))
            click_on t('forms.buttons.back')
            expect(page).to have_current_path(idv_how_to_verify_path)
          end
        end
      end

      context 'when the user is bucketed for Socure doc_auth' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return('socure')
          allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return('socure')
        end

        it 'goes to direct IPP if selected and can come back' do
          expect(page).to have_current_path(idv_how_to_verify_path)
          expect(page).to have_content(t('doc_auth.headings.how_to_verify'))
          click_on t('forms.buttons.continue_ipp')
          expect(page).to have_current_path(idv_document_capture_path(step: :how_to_verify))
          expect_in_person_step_indicator_current_step(
            t('step_indicator.flows.idv.find_a_post_office'),
          )
          expect(page).to have_content(t('headings.verify'))
          click_on t('forms.buttons.back')
          expect(page).to have_current_path(idv_how_to_verify_path)
        end
      end
    end

    context 'and when sp has not opted into ipp' do
      let(:in_person_proofing_opt_in_enabled) { true }
      let(:service_provider_in_person_proofing_enabled) { false }

      it 'skips when disabled and redirects to hybrid handoff' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end

  describe 'navigating to How To Verify from Agreement page in 50/50 state
   when the sp has opted into ipp' do
    context 'opt in false at start but true during navigation' do
      it 'should be bounced back from Hybrid Handoff to How to Verify' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        page.refresh
        expect(page).to have_current_path(idv_how_to_verify_url)
      end
    end

    context 'opt in true at start but false during navigation' do
      let(:in_person_proofing_opt_in_enabled) { true }

      it 'should be redirected to Hybrid Handoff page when opt in is false' do
        expect(page).to have_current_path(idv_how_to_verify_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        page.refresh
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end

    context 'Going back from Hybrid Handoff with opt in disabled midstream' do
      let(:in_person_proofing_opt_in_enabled) { true }
      before do
        click_on t('forms.buttons.continue_remote')
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
      it 'should go back to the Agreement step from Hybrid Handoff with opt in toggled midstream' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        page.go_back
        expect(page).to have_current_path(idv_agreement_url)
      end
    end

    context 'Going back from Hybrid Handoff with opt in enabled the whole time' do
      let(:in_person_proofing_opt_in_enabled) { true }
      before do
        click_on t('forms.buttons.continue_remote')
      end

      it 'should be bounced back to How to Verify' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        page.go_back
        expect(page).to have_current_path(idv_how_to_verify_url)
      end
    end

    context 'Going back from Hybrid Handoff with opt in disabled the whole time' do
      it 'should be not be bounced back to How to Verify' do
        expect(page).to have_current_path(idv_hybrid_handoff_url)
        page.go_back
        expect(page).to have_current_path(idv_agreement_url)
      end
    end

    context 'Going back from Document Capture with opt in disabled midstream' do
      let(:in_person_proofing_opt_in_enabled) { true }
      before do
        click_on t('forms.buttons.continue_ipp')
      end

      it 'should not be bounced back to How to Verify with opt in disabled midstream' do
        expect(page).to have_current_path(idv_document_capture_path(step: :how_to_verify))
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        page.go_back
        expect(page).to have_current_path(idv_document_capture_path)
        page.go_back
        expect(page).to have_current_path(idv_agreement_url)
      end
    end

    context 'Going back from Document Capture with opt in enabled midstream' do
      before do
        complete_hybrid_handoff_step
      end

      it 'should continue to Document Capture with opt in toggled midstream' do
        expect(page).to have_current_path(idv_document_capture_path)
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        page.go_back
        expect(page).to have_current_path(idv_document_capture_url)
      end
    end

    context 'Going back from Document Capture with opt in enabled the whole time' do
      let(:in_person_proofing_opt_in_enabled) { true }
      before do
        click_on t('forms.buttons.continue_ipp')
      end

      it 'should be bounced back to How to Verify' do
        expect(page).to have_current_path(idv_document_capture_path(step: :how_to_verify))
        page.go_back
        expect(page).to have_current_path(idv_how_to_verify_url)
      end
    end

    context 'Going back from Document Capture with opt in disabled the whole time' do
      before do
        complete_hybrid_handoff_step
      end

      it 'should be not be bounced back to how to verify' do
        expect(page).to have_current_path(idv_document_capture_path)
        page.go_back
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end
end

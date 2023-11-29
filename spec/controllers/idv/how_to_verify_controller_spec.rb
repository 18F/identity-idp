require 'rails_helper'

RSpec.describe Idv::HowToVerifyController do
  let(:user) { create(:user) }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
    stub_sign_in(user)
    stub_analytics
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given = true
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    context 'confirm_step_allowed' do
      context 'when ipp is disabled and ipp opt in is enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { false }
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        end

        it 'disables the how to verify step and redirects to hybrid handoff' do
          get :show

          expect(Idv::HowToVerifyController.enabled?).to be false
          expect(subject.idv_session.skip_doc_auth).to be_nil
          expect(response).to redirect_to(idv_hybrid_handoff_url)
        end
      end

      context 'when ipp is enabled but ipp opt in is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        end

        it 'disables the how to verify step and redirects to hybrid handoff' do
          get :show

          expect(Idv::HowToVerifyController.enabled?).to be false
          expect(subject.idv_session.skip_doc_auth).to be_nil
          expect(response).to redirect_to(idv_hybrid_handoff_url)
        end
      end

      context 'when at least 1 feature flag is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { false }
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        end

        it 'when both ipp is disabled and ipp opt in is disabled' do
          get :show

          expect(Idv::HowToVerifyController.enabled?).to be false
          expect(subject.idv_session.skip_doc_auth).to be_nil
          expect(response).to redirect_to(idv_hybrid_handoff_url)
        end
      end
    end

    context 'confirm_step_allowed' do
      it 'renders the show template when both feature flags are enabled' do
        get :show

        expect(Idv::HowToVerifyController.enabled?).to be true
        expect(subject.idv_session.skip_doc_auth).to be_nil
        expect(response).to render_template :show
      end
    end
  end

  describe '#show' do
    it 'renders the show template' do
      get :show

      expect(subject.idv_session.skip_doc_auth).to be_nil
      expect(response).to render_template :show
    end

    context 'agreement step not completed' do
      before do
        subject.idv_session.idv_consent_given = nil
      end

      it 'redirects to agreement path' do
        get :show

        expect(response).to redirect_to idv_agreement_path
      end
    end
  end

  describe '#update' do
    let(:params) do
      {
        idv_how_to_verify_form: { selection: selection },
      }
    end
    let(:selection) { 'remote' }

    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update
    end

    context 'remote' do
      it 'sets skip doc auth on idv session to false and redirects to hybrid handoff' do
        put :update, params: params

        expect(subject.idv_session.skip_doc_auth).to be false
        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end
    end

    context 'ipp' do
      let(:selection) { 'ipp' }

      it 'sets skip doc auth on idv session to true and redirects to document capture' do
        put :update, params: params

        expect(subject.idv_session.skip_doc_auth).to be true
        expect(response).to redirect_to(idv_document_capture_url)
      end
    end

    context 'undo/back' do
      it 'sets skip_doc_auth to nil and does not redirect' do
        put :update, params: { undo_step: true }

        expect(subject.idv_session.skip_doc_auth).to be_nil
        expect(response).to redirect_to(idv_how_to_verify_url)
      end
    end
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::HowToVerifyController.step_info).to be_valid
    end
  end
end

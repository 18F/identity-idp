require 'rails_helper'

RSpec.describe Idv::HowToVerifyController do
  let(:user) { create(:user) }
  let(:enabled) { true }
  let(:service_provider) do
    create(:service_provider, :active, :in_person_proofing_enabled)
  end
  let(:document_capture_session) { create(:document_capture_session, user:) }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
    stub_sign_in(user)
    stub_analytics
    allow(subject.idv_session).to receive(:service_provider).and_return(service_provider)
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given_at = Time.zone.now
    subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    context 'confirm_step_allowed' do
      context 'when ipp is disabled and opt-in ipp is enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { false }
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        end

        it 'disables the how to verify step and redirects to hybrid handoff' do
          get :show

          expect(Idv::HowToVerifyController.enabled?).to be false
          expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be_nil
          expect(response).to redirect_to(idv_hybrid_handoff_url)
        end
      end

      context 'when ipp is enabled but opt-in ipp is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        end

        it 'disables the how to verify step and redirects to hybrid handoff' do
          get :show

          expect(Idv::HowToVerifyController.enabled?).to be false
          expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be_nil
          expect(response).to redirect_to(idv_hybrid_handoff_url)
        end
      end

      context 'when both ipp and opt-in ipp are disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { false }
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { false }
        end

        it 'disables the how to verify step and redirects to hybrid handoff' do
          get :show

          expect(Idv::HowToVerifyController.enabled?).to be false
          expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be_nil
          expect(response).to redirect_to(idv_hybrid_handoff_url)
        end
      end

      context 'when both ipp and opt-in ipp are enabled' do
        context 'when the ServiceProvider has IPP enabled' do
          it 'renders the show template for how to verify' do
            get :show

            expect(Idv::HowToVerifyController.enabled?).to be true
            expect(subject.idv_session.service_provider.in_person_proofing_enabled).to be true
            expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be_nil
            expect(response).to render_template :show
          end
        end

        context 'when the ServiceProvider has IPP disabled' do
          let(:service_provider) do
            create(:service_provider, :active)
          end

          it 'redirects to hybrid_handoff' do
            get :show

            expect(Idv::HowToVerifyController.enabled?).to be true
            expect(subject.idv_session.service_provider.in_person_proofing_enabled).to be false
            expect(response).to redirect_to(idv_hybrid_handoff_url)
          end
        end
      end
    end
  end

  describe '#show' do
    let(:analytics_name) { :idv_doc_auth_how_to_verify_visited }
    let(:analytics_args) do
      {
        step: 'how_to_verify',
        analytics_id: 'Doc Auth',
      }
    end

    it 'renders the show template' do
      get :show

      expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be_nil
      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    context 'agreement step not completed' do
      before do
        subject.idv_session.idv_consent_given_at = nil
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
    let(:analytics_name) { :idv_doc_auth_how_to_verify_submitted }

    shared_examples_for 'invalid form submissions' do
      it 'invalidates future steps' do
        expect(subject).to receive(:clear_future_steps!)

        put :update
      end

      it 'logs the invalid value and re-renders the page' do
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
        expect(response).to render_template :show
      end

      it 'redirects to how_to_verify' do
        put :update, params: params

        expect(flash[:error]).not_to be_present
        expect(subject.idv_session.opted_in_to_in_person_proofing).to be_nil
      end
    end

    context 'no selection made' do
      let(:analytics_args) do
        {
          step: 'how_to_verify',
          analytics_id: 'Doc Auth',
          error_details: { selection: { blank: true } },
          success: false,
        }
      end

      let(:params) { nil }

      it_behaves_like 'invalid form submissions'
    end

    context 'an invalid selection is submitted' do
      # (This should only be possible if someone alters the form)
      let(:selection) { 'carrier_pigeon' }

      let(:analytics_args) do
        {
          step: 'how_to_verify',
          analytics_id: 'Doc Auth',
          selection:,
          error_details: { selection: { inclusion: true } },
          success: false,
        }
      end

      it_behaves_like 'invalid form submissions'
    end

    context 'remote' do
      let(:selection) { 'remote' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          step: 'how_to_verify',
          success: true,
          selection:,
        }
      end
      it 'sets skip doc auth on idv session to false and redirects to hybrid handoff' do
        put :update, params: params

        expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be false
        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end

      it 'sends analytics_submitted event when remote proofing is selected' do
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      context 'the user has an establishing in-person enrollment' do
        let(:user) { create(:user, :with_establishing_in_person_enrollment) }
        it 'cancels the establishing in-person enrollment' do
          expect(user.in_person_enrollments.first.status).to eq('establishing')

          put :update, params: params

          expect(user.in_person_enrollments.first.status).to eq('cancelled')
        end
      end
    end

    context 'ipp' do
      let(:selection) { 'ipp' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          step: 'how_to_verify',
          success: true,
          selection:,
        }
      end
      it 'sets skip doc auth on idv session to true and redirects to document capture' do
        put :update, params: params

        expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be true
        expect(response).to redirect_to(idv_document_capture_url(step: :how_to_verify))
      end

      it 'sends analytics_submitted event when remote proofing is selected' do
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end
    end
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::HowToVerifyController.step_info).to be_valid
    end
  end
end

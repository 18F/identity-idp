require 'rails_helper'

RSpec.describe Idv::AgreementController do
  include FlowPolicyHelper

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_up_to(:welcome, idv_session: subject.idv_session)
    stub_analytics
    stub_attempts_tracker
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_mail_only_outage,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth agreement visited' }
    let(:analytics_args) do
      {
        step: 'agreement',
        analytics_id: 'Doc Auth',
      }
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog agreement_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.agreement_view_count }.from(0).to(1),
      )
    end

    context 'welcome step is not complete' do
      it 'redirects to idv_welcome_url' do
        subject.idv_session.welcome_visited = nil

        get :show

        expect(response).to redirect_to(idv_welcome_url)
      end
    end

    context 'agreement already visited' do
      it 'does not redirect to hybrid_handoff' do
        stub_up_to(:agreement, idv_session: subject.idv_session)

        get :show

        expect(response).to render_template('idv/agreement/show')
      end

      context 'and verify info already completed' do
        before do
          stub_up_to(:verify_info, idv_session: subject.idv_session)
        end

        it 'renders the show template' do
          get :show
          expect(response).to render_template(:show)
        end
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth agreement submitted' }

    let(:analytics_args) do
      {
        success: true,
        step: 'agreement',
        analytics_id: 'Doc Auth',
      }
    end

    let(:skip_hybrid_handoff) { nil }

    let(:params) do
      {
        doc_auth: {
          idv_consent_given: 1,
        },
        skip_hybrid_handoff: skip_hybrid_handoff,
      }.compact
    end

    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update, params: params
    end

    it 'sends analytics_submitted event with consent given' do
      put :update, params: params

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'does not set flow_path' do
      expect do
        put :update, params: params
      end.not_to change {
        subject.idv_session.flow_path
      }.from(nil)
    end

    context 'with a non-proofed user' do
      it 'does not track a reproofing event during initial proofing' do
        expect(@attempts_api_tracker).not_to receive(:idv_reproof)

        put :update, params:
      end
    end

    context 'with a previously proofed user' do
      context 'with a deactivated profile' do
        before { create(:profile, :deactivated, user:) }

        it 'tracks a reproofing event upon reproofing' do
          expect(@attempts_api_tracker).to receive(:idv_reproof)
          put :update, params:
        end
      end

      context 'with an activated legacy idv  profile' do
        it 'does not track a reproofing event during initial proofing' do
          expect(@attempts_api_tracker).not_to receive(:idv_reproof)

          put :update, params:
        end
        context 'when IAL2 is needed' do
          before do
            create(:profile, :active, user:)
            resolved_authn_context_result = Vot::Parser.new(
              acr_values: Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
            ).parse
            allow(subject).to receive(:resolved_authn_context_result).and_return(
              resolved_authn_context_result,
            )
          end

          it 'tracks a reproofing event upon reproofing' do
            expect(@attempts_api_tracker).to receive(:idv_reproof)
            put :update, params:
          end
        end
      end
    end

    context 'on success' do
      let(:current_time) { Time.zone.now }

      before do
        freeze_time
        travel_to(current_time)
      end

      context 'when passports are allowed' do
        before do
          subject.idv_session.passport_allowed = true
        end

        context 'when skip_hybrid_handoff is set to true in params' do
          let(:skip_hybrid_handoff) { true }

          before do
            put :update, params: params
          end

          it 'sets opted_in_to_in_person_proofing to false on IDV session' do
            expect(subject.idv_session.opted_in_to_in_person_proofing).to be(false)
          end

          it 'sets an idv_consent_given_at timestamp' do
            expect(subject.idv_session.idv_consent_given_at).to eq(current_time)
          end

          it 'redirects to idv_choose_id_type' do
            expect(response).to redirect_to(idv_choose_id_type_url)
          end
        end

        context 'when skip_hybrid_handoff is not set in params' do
          let(:skip_hybrid_handoff) { nil }

          before do
            put :update, params: params
          end

          it 'sets an idv_consent_given_at timestamp' do
            expect(subject.idv_session.idv_consent_given_at).to eq(current_time)
          end

          it 'sets opted_in_to_in_person_proofing to false on IDV session' do
            expect(subject.idv_session.opted_in_to_in_person_proofing).to be(false)
          end

          it 'sets skip_doc_auth_from_how_to_verify to false on IDV session' do
            expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be(false)
          end

          it 'redirects to hybrid handoff with new content' do
            expect(response).to redirect_to(idv_hybrid_handoff_url)
          end
        end
      end

      context 'when passports are not allowed' do
        before do
          subject.idv_session.passport_allowed = false
        end

        context 'when skip_hybrid_handoff is set to true in params' do
          let(:skip_hybrid_handoff) { true }

          before do
            put :update, params: params
          end

          it 'sets an idv_consent_given_at timestamp' do
            expect(subject.idv_session.idv_consent_given_at).to eq(current_time)
          end

          it 'sets opted_in_to_in_person_proofing to false on IDV session' do
            expect(subject.idv_session.opted_in_to_in_person_proofing).to be(false)
          end

          it 'sets skip_doc_auth_from_how_to_verify to false on IDV session' do
            expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be(false)
          end

          it 'redirects to hybrid handoff with new content' do
            expect(response).to redirect_to(idv_hybrid_handoff_url)
          end
        end

        context 'when skip_hybrid_handoff is not set in params' do
          let(:skip_hybrid_handoff) { nil }

          before do
            put :update, params: params
          end

          it 'sets an idv_consent_given_at timestamp' do
            expect(subject.idv_session.idv_consent_given_at).to eq(current_time)
          end

          it 'sets opted_in_to_in_person_proofing to false on IDV session' do
            expect(subject.idv_session.opted_in_to_in_person_proofing).to be(false)
          end

          it 'sets skip_doc_auth_from_how_to_verify to false on IDV session' do
            expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to be(false)
          end

          it 'redirects to hybrid handoff with new content' do
            expect(response).to redirect_to(idv_hybrid_handoff_url)
          end
        end
      end
    end

    context 'on failure' do
      let(:skip_hybrid_handoff) { nil }

      let(:params) do
        {
          doc_auth: {
            idv_consent_given: nil,
          },
          skip_hybrid_handoff: skip_hybrid_handoff,
        }.compact
      end

      it 'renders the form again' do
        put :update, params: params
        expect(response).to render_template('idv/agreement/show')
      end

      it 'does not set IDV consent flags' do
        put :update, params: params

        expect(subject.idv_session.idv_consent_given?).to eq(false)
        expect(subject.idv_session.idv_consent_given_at).to be_nil
      end
    end
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::AgreementController.step_info).to be_valid
    end

    context 'undo_step' do
      before do
        subject.idv_session.idv_consent_given_at = Time.zone.now
        subject.idv_session.skip_hybrid_handoff = false
        subject.idv_session.opted_in_to_in_person_proofing = false
        described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
      end

      it 'sets the idv session idv_consent_given_at to nil' do
        expect(subject.idv_session.idv_consent_given_at).to be_nil
      end

      it 'sets the idv session skip_hybrid_handoff to nil' do
        expect(subject.idv_session.skip_hybrid_handoff).to be_nil
      end

      it 'sets the idv session opted_in_to_in_person_proofing to nil' do
        expect(subject.idv_session.opted_in_to_in_person_proofing).to be_nil
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Idv::PhoneQuestionController do
  let(:user) { create(:user) }

  let(:analytics_args) do
    {
      step: 'phone_question',
      analytics_id: 'Doc Auth',
      skip_hybrid_handoff: nil,
      irs_reproofing: false,
    }.merge(ab_test_args)
  end

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    stub_analytics
    stub_attempts_tracker
    subject.user_session['idv/doc_auth'] = {}
    subject.idv_session.idv_consent_given = true
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
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

    it 'checks that agreement step is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_agreement_step_complete,
      )
    end

    it 'checks that hybrid_handoff is needed' do
      expect(subject).to have_actions(
        :before,
        :confirm_hybrid_handoff_needed,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { :idv_doc_auth_phone_question_visited }

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    context 'when rendered' do
      render_views

      it 'displays phone question header' do
        get :show

        expect(response.body).to include(t('doc_auth.headings.phone_question'))
      end
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    context 'agreement step is not complete' do
      before do
        subject.idv_session.idv_consent_given = nil
      end

      it 'redirects to idv_agreement_url' do
        get :show

        expect(response).to redirect_to(idv_agreement_url)
      end
    end

    context 'confirm_hybrid_handoff_needed before action' do
      context 'standard flow_path already defined' do
        it 'redirects to document_capture in standard flow' do
          subject.idv_session.flow_path = 'standard'

          get :show

          expect(response).to redirect_to(idv_document_capture_url)
        end

        it 'redirects to link_sent in hybrid flow' do
          subject.idv_session.flow_path = 'hybrid'

          get :show

          expect(response).to redirect_to(idv_link_sent_url)
        end
      end

      context 'on mobile device' do
        it 'redirects to document_capture' do
          subject.idv_session.skip_hybrid_handoff = true

          get :show

          expect(response).to redirect_to(idv_document_capture_url)
        end
      end

      context 'hybrid flow is not available' do
        before do
          allow(FeatureManagement).to receive(:idv_allow_hybrid_flow?).and_return(false)
        end

        it 'redirects the user straight to document capture' do
          get :show
          expect(response).to redirect_to(idv_document_capture_url)
        end
      end
    end
  end

  describe '#phone_with_camera' do
    let(:analytics_name) { :idv_doc_auth_phone_question_submitted }

    it 'redirects to hybrid handoff' do
      get :phone_with_camera

      expect(response).to redirect_to(idv_hybrid_handoff_url)
    end

    it 'sends analytics submitted event' do
      get :phone_with_camera

      expect(@analytics).
        to have_logged_event(analytics_name, analytics_args.merge!(phone_with_camera: true))
    end
  end

  describe '#phone_without_camera' do
    let(:analytics_name) { :idv_doc_auth_phone_question_submitted }

    it 'redirects to hybrid handoff' do
      get :phone_without_camera

      expect(response).to redirect_to(idv_hybrid_handoff_url)
    end

    it 'sends analytics submitted event' do
      get :phone_without_camera

      expect(@analytics).
        to have_logged_event(analytics_name, analytics_args.merge!(phone_with_camera: false))
    end

    it 'set idv_session flow path to standard' do
      expect { get :phone_without_camera }.
        to change { subject.idv_session.flow_path }.from(nil).to 'standard'
    end
  end
end

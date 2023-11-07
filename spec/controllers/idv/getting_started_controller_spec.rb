require 'rails_helper'

RSpec.describe Idv::GettingStartedController do
  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    stub_analytics
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
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth getting_started visited' }
    let(:analytics_args) do
      {
        step: 'getting_started',
        analytics_id: 'Doc Auth',
        skip_hybrid_handoff: nil,
        irs_reproofing: false,
      }.merge(ab_test_args)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog welcome_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.welcome_view_count }.from(0).to(1),
      )
    end

    it 'updates DocAuthLog agreement_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.agreement_view_count }.from(0).to(1),
      )
    end

    context 'document capture already completed' do
      before do
        subject.idv_session.pii_from_doc = { first_name: 'Susan' }
      end

      it 'redirects to ssn step' do
        get :show
        expect(response).to redirect_to(idv_ssn_url)
      end
    end

    it 'redirects to please call page if fraud review is pending' do
      profile = create(:profile, :fraud_review_pending)

      stub_sign_in(profile.user)

      get :show

      expect(response).to redirect_to(idv_please_call_url)
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth getting_started submitted' }

    let(:analytics_args) do
      {
        success: true,
        errors: {},
        step: 'getting_started',
        analytics_id: 'Doc Auth',
        skip_hybrid_handoff: nil,
        irs_reproofing: false,
      }.merge(ab_test_args)
    end

    let(:skip_hybrid_handoff) { nil }

    let(:params) do
      {
        doc_auth: {
          idv_consent_given: 1,
        },
        skip_hybrid_handoff:,
      }.compact
    end

    it 'sends analytics_submitted event with consent given' do
      put(:update, params:)

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'creates a document capture session' do
      expect { put :update, params: }.
        to change { subject.idv_session.document_capture_session_uuid }.from(nil)
    end

    context 'with previous establishing in-person enrollments' do
      let!(:enrollment) { create(:in_person_enrollment, :establishing, user:, profile: nil) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'cancels all previous establishing enrollments' do
        put(:update, params:)

        expect(enrollment.reload.status).to eq(InPersonEnrollment::STATUS_CANCELLED)
        expect(user.establishing_in_person_enrollment).to be_blank
      end
    end

    it 'does not set flow_path' do
      expect do
        put :update, params:
      end.not_to change {
        subject.idv_session.flow_path
      }.from(nil)
    end

    it 'redirects to hybrid handoff' do
      put(:update, params:)
      expect(response).to redirect_to(idv_hybrid_handoff_url)
    end

    context 'skip_hybrid_handoff present in params' do
      let(:skip_hybrid_handoff) { '' }
      it 'sets flow_path to standard' do
        expect do
          put :update, params:
        end.to change {
          subject.idv_session.flow_path
        }.from(nil).to('standard').and change {
          subject.idv_session.skip_hybrid_handoff
        }.from(nil).to(true)
      end

      it 'redirects to hybrid handoff' do
        put(:update, params:)
        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Idv::WelcomeController do
  include IdvHelper

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
    subject.user_session['idv/doc_auth'] = {}
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
        :check_for_outage,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth welcome visited' }
    let(:analytics_args) do
      { step: 'welcome',
        analytics_id: 'Doc Auth',
        irs_reproofing: false }
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

    context 'welcome already visited' do
      it 'redirects to agreement' do
        subject.idv_session.welcome_visited = true

        get :show

        expect(response).to redirect_to(idv_agreement_url)
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
    let(:analytics_name) { 'IdV: doc auth welcome submitted' }

    let(:analytics_args) do
      { step: 'welcome',
        analytics_id: 'Doc Auth',
        irs_reproofing: false }
    end

    it 'sends analytics_submitted event' do
      put :update

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'creates a document capture session' do
      expect { put :update }.
        to change { subject.user_session['idv/doc_auth'][:document_capture_session_uuid] }.from(nil)
    end

    context 'with previous establishing in-person enrollments' do
      let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user, profile: nil) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'cancels all previous establishing enrollments' do
        put :update

        expect(enrollment.reload.status).to eq('cancelled')
        expect(user.establishing_in_person_enrollment).to be_blank
      end
    end
  end
end

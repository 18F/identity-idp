require 'rails_helper'

RSpec.describe Idv::WelcomeController do
  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    stub_analytics
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::WelcomeController.step_info).to be_valid
    end
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

    it 'includes getting started ab test before_action' do
      expect(subject).to have_actions(
        :before,
        :maybe_redirect_for_getting_started_ab_test,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth welcome visited' }
    let(:analytics_args) do
      {
        step: 'welcome',
        analytics_id: 'Doc Auth',
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

    context 'welcome already visited' do
      it 'does not redirect to agreement' do
        subject.idv_session.welcome_visited = true

        get :show

        expect(response).to render_template('idv/welcome/show')
      end

      context 'and verify info already completed' do
        before do
          subject.idv_session.flow_path = 'standard'
          subject.idv_session.pii_from_doc = { first_name: 'Susan' }
          subject.idv_session.ssn = '123-45-6789'
          subject.idv_session.resolution_successful = true
        end

        it 'redirects to enter password step' do
          get :show
          expect(response).to redirect_to(idv_enter_password_url)
        end
      end
    end

    it 'redirects to please call page if fraud review is pending' do
      profile = create(:profile, :fraud_review_pending)

      stub_sign_in(profile.user)

      get :show

      expect(response).to redirect_to(idv_please_call_url)
    end

    context 'getting_started_ab_test_bucket values' do
      render_views

      it 'renders the welcome_new template for :welcome_new' do
        allow(controller).to receive(:getting_started_ab_test_bucket).and_return(:welcome_new)

        get :show
        expect(response).to render_template(partial: '_welcome_new')
      end

      it 'it renders the welcome_default template for :welcome_default' do
        allow(controller).to receive(:getting_started_ab_test_bucket).and_return(:welcome_default)

        get :show
        expect(response).to render_template(partial: '_welcome_default')
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth welcome submitted' }

    let(:analytics_args) do
      {
        step: 'welcome',
        analytics_id: 'Doc Auth',
        irs_reproofing: false,
      }.merge(ab_test_args)
    end

    it 'sends analytics_submitted event' do
      put :update

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update
    end

    it 'creates a document capture session' do
      expect { put :update }.
        to change { subject.idv_session.document_capture_session_uuid }.from(nil)
    end

    context 'with previous establishing in-person enrollments' do
      let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user, profile: nil) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'cancels all previous establishing enrollments' do
        put :update

        expect(enrollment.reload.status).to eq(InPersonEnrollment::STATUS_CANCELLED)
        expect(user.establishing_in_person_enrollment).to be_blank
      end
    end
  end
end

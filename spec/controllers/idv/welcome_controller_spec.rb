require 'rails_helper'

RSpec.describe Idv::WelcomeController do
  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
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

    it 'includes cancelling previous in person enrollments' do
      expect(subject).to have_actions(
        :before,
        :cancel_previous_in_person_enrollments,
      )
    end

    context 'with previous establishing and pending in-person enrollments' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      let!(:establishing_enrollment) { create(:in_person_enrollment, :establishing, user: user) }
      let(:password_reset_profile) { create(:profile, :password_reset, user: user) }
      let!(:pending_enrollment) do
        create(:in_person_enrollment, :pending, user: user, profile: password_reset_profile)
      end
      let(:fraud_password_reset_profile) { create(:profile, :password_reset, user: user) }
      let!(:fraud_review_enrollment) do
        create(
          :in_person_enrollment, :in_fraud_review, user: user, profile: fraud_password_reset_profile
        )
      end

      it 'cancels all previous establishing, pending, and in_fraud_review enrollments' do
        put :show

        expect(establishing_enrollment.reload.status).to eq(InPersonEnrollment::STATUS_CANCELLED)
        expect(pending_enrollment.reload.status).to eq(InPersonEnrollment::STATUS_CANCELLED)
        expect(fraud_review_enrollment.reload.status).to eq(InPersonEnrollment::STATUS_CANCELLED)
        expect(user.establishing_in_person_enrollment).to be_blank
        expect(user.pending_in_person_enrollment).to be_blank
      end
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth welcome visited' }
    let(:analytics_args) do
      {
        step: 'welcome',
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

    it 'updates DocAuthLog welcome_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.welcome_view_count }.from(0).to(1),
      )
    end

    it 'sets the proofing started timestamp', :freeze_time do
      get :show

      expect(subject.idv_session.proofing_started_at).to eq(Time.zone.now.iso8601)
    end

    context 'passports are enabled' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      end

      it 'sets passport_allowed in idv session' do
        get :show

        expect(subject.idv_session.passport_allowed).to eq(true)
      end
    end

    context 'welcome already visited' do
      before do
        subject.idv_session.welcome_visited = true
        subject.idv_session.proofing_started_at = 5.minutes.ago.iso8601
      end

      it 'does not redirect to agreement' do
        get :show

        expect(response).to render_template('idv/welcome/show')
      end

      it 'does not overwrite the proofing started timestamp' do
        expect { get :show }.to_not change { subject.idv_session.proofing_started_at }
      end

      context 'and verify info already completed' do
        before do
          subject.idv_session.flow_path = 'standard'
          subject.idv_session.pii_from_doc = Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT)
          subject.idv_session.ssn = '123-45-6789'
          subject.idv_session.resolution_successful = true
        end

        it 'renders show' do
          get :show
          expect(response).to render_template('idv/welcome/show')
        end
      end
    end

    it 'redirects to please call page if fraud review is pending' do
      profile = create(:profile, :fraud_review_pending)

      stub_sign_in(profile.user)

      get :show

      expect(response).to redirect_to(idv_please_call_url)
    end

    context 'has pending in-person enrollment' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'redirects to ready to verify' do
        profile = create(:profile, :in_person_verification_pending, user:)

        stub_sign_in(profile.user)

        get :show

        expect(response).to redirect_to(idv_in_person_ready_to_verify_url)
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth welcome submitted' }

    let(:analytics_args) do
      {
        step: 'welcome',
        analytics_id: 'Doc Auth',
      }
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
      expect { put :update }
        .to change { subject.idv_session.document_capture_session_uuid }.from(nil)
    end
  end
end

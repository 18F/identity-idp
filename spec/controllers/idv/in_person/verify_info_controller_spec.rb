require 'rails_helper'

describe Idv::InPerson::VerifyInfoController do
  include IdvHelper

  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      :pii_from_user => Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup,
      :flow_path => 'standard' }
  end

  let(:user) { build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' }) }
  let(:service_provider) { create(:service_provider) }

  before do
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'confirms ssn step complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_ssn_step_complete,
      )
    end

    it 'confirms verify step not already complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_verify_info_step_needed,
      )
    end

    it 'renders 404 if feature flag not set' do
      allow(IdentityConfig.store).to receive(:in_person_verify_info_controller_enabled).
        and_return(false)

      get :show

      expect(response).to be_not_found
    end
  end

  context 'when in_person_verify_info_controller_enabled' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_verify_info_controller_enabled).
        and_return(true)
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
    end

    describe '#show' do
      let(:analytics_name) { 'IdV: doc auth verify visited' }
      let(:analytics_args) do
        {
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'verify',
          step_count: 1,
        }
      end

      it 'renders the show template' do
        get :show

        expect(response).to render_template :show
      end

      it 'sends analytics_visited event' do
        get :show

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end

      it 'sends correct step count to analytics' do
        get :show
        get :show
        analytics_args[:step_count] = 2

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end
    end

    describe '#update' do
      it 'sets uuid_prefix on pii_from_user' do
        expect(Idv::Agent).to receive(:new).
          with(hash_including(uuid_prefix: service_provider.app_id)).and_call_original

        put :update

        expect(flow_session[:pii_from_user][:uuid_prefix]).to eq service_provider.app_id
      end

      it 'passes the X-Amzn-Trace-Id to the proofer' do
        expect_any_instance_of(Idv::Agent).to receive(:proof_resolution).
          with(
            kind_of(DocumentCaptureSession),
            should_proof_state_id: anything,
            trace_id: subject.send(:amzn_trace_id),
            threatmetrix_session_id: nil,
            user_id: anything,
            request_ip: request.remote_ip,
          )

        put :update
      end

      it 'only enqueues a job once' do
        put :update
        expect_any_instance_of(Idv::Agent).to_not receive(:proof_resolution)

        put :update
      end

      context 'when pii_from_user is blank' do
        it 'redirects' do
          flow_session[:pii_from_user] = {}
          put :update
          expect(response.status).to eq 302
        end
      end

      context 'when different users use the same SSN within the same timeframe' do
        let(:user2) { create(:user) }

        before do
          allow(IdentityConfig.store).to receive(:proof_ssn_max_attempts).and_return(3)
          allow(IdentityConfig.store).to receive(:proof_ssn_max_attempt_window_in_minutes).
            and_return(10)
        end

        it 'throttles them all' do
          put :update
          #          expect_any_instance_of(Idv::Agent).to receive(:proof_resolution)
          subject.idv_session.verify_info_step_document_capture_session_uuid = nil
          put :update
          #          expect_any_instance_of(Idv::Agent).to receive(:proof_resolution)
          subject.idv_session.verify_info_step_document_capture_session_uuid = nil

          put :update
          expect_any_instance_of(Idv::Agent).to_not receive(:proof_resolution)
          expect(response).to redirect_to(idv_session_errors_ssn_failure_url)
          subject.idv_session.verify_info_step_document_capture_session_uuid = nil

          stub_sign_in(user2)
          put :update
          expect_any_instance_of(Idv::Agent).to_not receive(:proof_resolution)
          expect(response).to redirect_to(idv_session_errors_ssn_failure_url)
        end
      end

      it 'updates proofing component vendor' do
        put :update

        expect(user.proofing_component.document_check).to eq Idp::Constants::Vendors::USPS
      end
    end
  end
end

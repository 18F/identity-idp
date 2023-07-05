require 'rails_helper'

RSpec.describe Idv::InPerson::VerifyInfoController do
  include IdvHelper

  let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.dup }
  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      :pii_from_user => pii_from_user,
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

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_outage,
      )
    end

    it 'confirms ssn step complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_ssn_step_complete,
      )
    end

    it 'confirms verify step needed' do
      expect(subject).to have_actions(
        :before,
        :confirm_verify_info_step_needed,
      )
    end
  end

  before do
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
        same_address_as_id: true,
        pii_like_keypaths: [[:same_address_as_id], [:state_id, :state_id_jurisdiction]],
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
  end

  describe '#update' do
    it 'redirects to the expected page' do
      put :update

      expect(response).to redirect_to idv_in_person_verify_info_url
    end

    context 'double address verification is not enabled' do
      let(:capture_secondary_id_enabled) { false }
      let(:enrollment) { InPersonEnrollment.new(capture_secondary_id_enabled:) }
      before do
        allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
      end

      it 'sets uuid_prefix and state_id_type on pii_from_user' do
        expect(Idv::Agent).to receive(:new).
          with(hash_including(uuid_prefix: service_provider.app_id)).and_call_original
        # our test data already has the expected value by default
        flow_session[:pii_from_user].delete(:state_id_type)

        put :update

        expect(flow_session[:pii_from_user][:state_id_type]).to eq 'drivers_license'
        expect(flow_session[:pii_from_user][:uuid_prefix]).to eq service_provider.app_id
      end

      context 'a user does not have an establishing in person enrollment associated with them' do
        before do
          allow(user).to receive(:establishing_in_person_enrollment).and_return(nil)
        end

        it 'disables double address verification for the user' do
          expect_any_instance_of(Idv::Agent).to receive(:proof_resolution).
            with(
              kind_of(DocumentCaptureSession),
              should_proof_state_id: anything,
              trace_id: subject.send(:amzn_trace_id),
              threatmetrix_session_id: nil,
              user_id: anything,
              request_ip: request.remote_ip,
              double_address_verification: false,
            )

          put :update
        end
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
            double_address_verification: false,
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

        it 'rate limits them all' do
          put :update
          subject.idv_session.verify_info_step_document_capture_session_uuid = nil
          put :update
          subject.idv_session.verify_info_step_document_capture_session_uuid = nil
          put :update
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
    end

    context 'double address verification is enabled' do
      let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.dup }
      let(:capture_secondary_id_enabled) { true }
      let(:enrollment) { InPersonEnrollment.new(capture_secondary_id_enabled:) }
      before do
        allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
      end
      it 'captures state id address fields in the pii' do
        expect(Idv::Agent).to receive(:new).
          with(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.merge(uuid_prefix: nil)).
          and_call_original
        put :update
      end

      it 'indicates to the IDV agent that double_address_verification is enabled' do
        expect_any_instance_of(Idv::Agent).to receive(:proof_resolution).with(
          kind_of(DocumentCaptureSession),
          should_proof_state_id: anything,
          trace_id: anything,
          threatmetrix_session_id: anything,
          user_id: anything,
          request_ip: anything,
          double_address_verification: true,
        )

        put :update
      end
    end
  end
end

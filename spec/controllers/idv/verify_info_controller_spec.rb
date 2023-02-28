require 'rails_helper'

describe Idv::VerifyInfoController do
  include IdvHelper

  let(:flow_session) do
    { 'error_message' => nil,
      'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      :pii_from_doc => Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup,
      'threatmetrix_session_id' => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
      :flow_path => 'standard' }
  end

  let(:user) { create(:user) }

  before do
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_idv_steps_before_verify_step(user)
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
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth verify visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'standard',
        irs_reproofing: false,
        step: 'verify',
        step_count: 1,
      }
    end

    before do
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
      allow(@irs_attempts_api_tracker).to receive(:track_event)
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

    it 'updates DocAuthLog verify_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.verify_view_count }.from(0).to(1),
      )
    end

    context 'when the user has already verified their info' do
      it 'redirects to the review controller' do
        controller.idv_session.profile_confirmation = true

        get :show

        expect(response).to redirect_to(idv_review_url)
      end
    end

    context 'when the user is ssn throttled' do
      before do
        Throttle.new(
          target: Pii::Fingerprinter.fingerprint(
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          ),
          throttle_type: :proof_ssn,
        ).increment_to_throttled!
      end

      context 'when using new ssn controller' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_ssn_controller_enabled).
            and_return(true)
        end

        it 'redirects to ssn controller when ssn info is missing' do
          flow_session[:pii_from_doc][:ssn] = nil

          get :show

          expect(response).to redirect_to(idv_ssn_url)
        end
      end

      context 'when the user is ssn throttled' do
        before do
          Throttle.new(
            target: Pii::Fingerprinter.fingerprint(
              Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
            ),
            throttle_type: :proof_ssn,
          ).increment_to_throttled!
        end

        it 'redirects to ssn failure url' do
          get :show

          expect(response).to redirect_to idv_session_errors_ssn_failure_url
        end
      end
    end

    context 'when the user is proofing throttled' do
      before do
        Throttle.new(
          user: subject.current_user,
          throttle_type: :idv_resolution,
        ).increment_to_throttled!
      end

      it 'redirects to throttled url' do
        get :show

        expect(response).to redirect_to idv_session_errors_failure_url
      end
    end

    context 'when proofing_device_profiling is enabled' do
      let(:idv_result) do
        {
          context: {
            stages: {
              threatmetrix: {
                transaction_id: 1,
                review_status: review_status,
                response_body: {
                  tmx_summary_reason_code: ['Identity_Negative_History'],
                },
              },
            },
          },
          errors: {},
          exception: nil,
          success: true,
        }
      end

      let(:document_capture_session) do
        document_capture_session = DocumentCaptureSession.create!(user: user)
        document_capture_session.create_proofing_session
        document_capture_session.store_proofing_result(idv_result)
        document_capture_session
      end

      let(:expected_failure_reason) { { tmx_summary_reason_code: ['Identity_Negative_History'] } }

      before do
        controller.
          idv_session.verify_info_step_document_capture_session_uuid = document_capture_session.uuid
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
      end

      context 'when threatmetrix response is Pass' do
        let(:review_status) { 'pass' }

        it 'it logs IRS idv_tmx_fraud_check event' do
          expect(@irs_attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: true,
            failure_reason: nil,
          )
          get :show
        end
      end

      context 'when threatmetrix response is No Result' do
        let(:review_status) { 'no_result' }

        it 'it logs IRS idv_tmx_fraud_check event' do
          expect(@irs_attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: false,
            failure_reason: expected_failure_reason,
          )
          get :show
        end
      end

      context 'when threatmetrix response is Reject' do
        let(:review_status) { 'reject' }

        it 'it logs IRS idv_tmx_fraud_check event' do
          expect(@irs_attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: false,
            failure_reason: expected_failure_reason,
          )
          get :show
        end
      end

      context 'when threatmetrix response is Review' do
        let(:review_status) { 'review' }

        it 'it logs IRS idv_tmx_fraud_check event' do
          expect(@irs_attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: false,
            failure_reason: expected_failure_reason,
          )
          get :show
        end
      end
    end
  end

  describe '#update' do
    it 'logs the correct analytics event' do
      stub_analytics
      stub_attempts_tracker

      put :update

      expect(@analytics).to have_logged_event(
        'IdV: doc auth verify submitted',
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'verify',
          step_count: 0,
        },
      )
    end

    it 'updates DocAuthLog verify_submit_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { put :update }.to(
        change { doc_auth_log.reload.verify_submit_count }.from(0).to(1),
      )
    end

    context 'when the user is ssn throttled' do
      before do
        Throttle.new(
          target: Pii::Fingerprinter.fingerprint(
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          ),
          throttle_type: :proof_ssn,
        ).increment_to_throttled!
      end

      it 'redirects to ssn failure url' do
        put :update

        expect(response).to redirect_to idv_session_errors_ssn_failure_url
      end
    end

    context 'when the user is proofing throttled' do
      before do
        Throttle.new(
          user: subject.current_user,
          throttle_type: :idv_resolution,
        ).increment_to_throttled!
      end

      it 'redirects to throttled url' do
        put :update

        expect(response).to redirect_to idv_session_errors_failure_url
      end
    end
  end
end

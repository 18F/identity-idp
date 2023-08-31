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
  let(:analytics_hash) do
    {
      analytics_id: 'Doc Auth',
      flow_path: 'standard',
      irs_reproofing: false,
      step: 'verify',
    }
  end
  let(:ssn_throttle_hash) { { throttle_context: 'multi-session' } }
  let(:proofing_throttle_hash) { { throttle_context: 'single-session' } }

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

    it 'updates DocAuthLog verify_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.verify_view_count }.from(0).to(1),
      )
    end

    context 'address line 2' do
      render_views

      it 'With address2 in PII, shows address line 2 input' do
        flow_session[:pii_from_doc][:address2] = 'APT 3E'
        get :show

        expect(response.body).to have_content(t('idv.form.address2'))
      end

      it 'No address2 in PII, still shows address line 2 input' do
        flow_session[:pii_from_doc][:address2] = nil

        get :show

        expect(response.body).to have_content(t('idv.form.address2'))
      end
    end

    context 'when the user has already verified their info' do
      it 'redirects to the review controller' do
        controller.idv_session.resolution_successful = true

        get :show

        expect(response).to redirect_to(idv_review_url)
      end
    end

    it 'redirects to ssn controller when ssn info is missing' do
      flow_session[:pii_from_doc][:ssn] = nil

      get :show

      expect(response).to redirect_to(idv_ssn_url)
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

      it 'logs the correct attempts event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with(ssn_throttle_hash)

        get :show
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

      it 'logs the correct attempts event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with(proofing_throttle_hash)

        get :show
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
          threatmetrix_review_status: review_status,
        }
      end

      let(:document_capture_session) do
        document_capture_session = DocumentCaptureSession.create!(user: user)
        document_capture_session.create_proofing_session
        document_capture_session.store_proofing_result(idv_result)
        document_capture_session
      end

      let(:expected_failure_reason) { DocAuthHelper::SAMPLE_TMX_SUMMARY_REASON_CODE }

      before do
        controller.
          idv_session.verify_info_step_document_capture_session_uuid = document_capture_session.uuid
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
        allow(IdentityConfig.store).to receive(:irs_attempt_api_track_tmx_fraud_check_event).
          and_return(true)
      end

      context 'when threatmetrix response is Pass' do
        let(:review_status) { 'pass' }

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('pass')
        end

        it 'it logs IRS idv_tmx_fraud_check event' do
          expect(@irs_attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: true,
            failure_reason: nil,
          )
          get :show
        end
      end

      context 'when threatmetrix response is No Result' do
        let(:review_status) { nil }

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to be_nil
        end

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

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('reject')
        end

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

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('review')
        end

        it 'it logs IRS idv_tmx_fraud_check event' do
          expect(@irs_attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: false,
            failure_reason: expected_failure_reason,
          )
          get :show
        end
      end
    end

    context 'when aamva has trouble' do
      let(:document_capture_session) do
        DocumentCaptureSession.create(user:)
      end

      let(:async_state) do
        # Here we're trying to match the store to redis -> read from redis flow this data travels
        result = Proofing::Resolution::ResultAdjudicator.new(
          state_id_result: Proofing::StateIdResult.new(
            success: false,
            errors: {},
            exception: Proofing::Aamva::VerificationError.new('ExceptionId: 0001'),
            vendor_name: nil,
            transaction_id: '',
            verified_attributes: [],
          ),
          device_profiling_result: Proofing::DdpResult.new(success: true),
          double_address_verification: false,
          residential_resolution_result: Proofing::Resolution::Result.new(success: true),
          resolution_result: Proofing::Resolution::Result.new(success: true),
          same_address_as_id: true,
          should_proof_state_id: true,
        )

        document_capture_session.create_proofing_session

        document_capture_session.store_proofing_result(result.adjudicated_result.to_h)

        document_capture_session.load_proofing_result
      end

      before do
        stub_analytics
        allow(controller).to receive(:load_async_state).and_return(async_state)
        put :show
      end

      it 'redirects user to warning' do
        expect(response).to redirect_to idv_session_errors_state_id_warning_url
      end

      it 'logs an event' do
        expect(@analytics).to have_logged_event(
          'IdV: doc auth warning visited',
          step_name: 'Idv::VerifyInfoController',
          remaining_attempts: kind_of(Numeric),
        )
      end
    end
  end

  describe '#update' do
    before do
      stub_attempts_tracker
    end

    it 'logs the correct analytics event' do
      stub_analytics

      put :update

      expect(@analytics).to have_logged_event(
        'IdV: doc auth verify submitted',
        **analytics_hash,
      )
    end

    it 'redirects to the expected page' do
      put :update

      expect(response).to redirect_to idv_verify_info_url
    end

    it 'modifies pii as expected' do
      app_id = 'hello-world'
      sp = create(:service_provider, app_id: app_id)
      sp_session = { issuer: sp.issuer }
      allow(controller).to receive(:sp_session).and_return(sp_session)

      put :update

      expect(flow_session[:pii_from_doc][:uuid_prefix]).to eq app_id
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

      it 'logs the correct attempts event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with(ssn_throttle_hash)

        put :update
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

      it 'logs the correct attempts event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with(proofing_throttle_hash)

        put :update
      end
    end
  end
end

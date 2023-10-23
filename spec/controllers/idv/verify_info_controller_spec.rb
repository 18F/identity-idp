require 'rails_helper'

RSpec.describe Idv::VerifyInfoController do
  let(:user) { create(:user) }
  let(:analytics_hash) do
    {
      analytics_id: 'Doc Auth',
      flow_path: 'standard',
      irs_reproofing: false,
      step: 'verify',
    }.merge(ab_test_args)
  end

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_analytics
    stub_attempts_tracker
    stub_idv_steps_before_verify_step(user)
    subject.idv_session.flow_path = 'standard'
    subject.idv_session.pii_from_doc = Idp::Constants::MOCK_IDV_APPLICANT.dup
    subject.idv_session.ssn = Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn]
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

    it 'updates DocAuthLog verify_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.verify_view_count }.from(0).to(1),
      )
    end

    context 'address line 2' do
      render_views

      it 'With address2 in PII, shows address line 2 input' do
        subject.idv_session.pii_from_doc[:address2] = 'APT 3E'
        get :show

        expect(response.body).to have_content(t('idv.form.address2'))
      end

      it 'No address2 in PII, still shows address line 2 input' do
        subject.idv_session.pii_from_doc[:address2] = nil

        get :show

        expect(response.body).to have_content(t('idv.form.address2'))
      end
    end

    context 'when the user has already verified their info' do
      it 'redirects to the enter password controller' do
        subject.idv_session.resolution_successful = true

        get :show

        expect(response).to redirect_to(idv_review_url)
      end
    end

    it 'redirects to ssn controller when ssn info is missing' do
      subject.idv_session.ssn = nil

      get :show

      expect(response).to redirect_to(idv_ssn_url)
    end

    context 'when the user is ssn rate limited' do
      before do
        RateLimiter.new(
          target: Pii::Fingerprinter.fingerprint(
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          ),
          rate_limit_type: :proof_ssn,
        ).increment_to_limited!
      end

      it 'redirects to ssn failure url' do
        get :show

        expect(response).to redirect_to idv_session_errors_ssn_failure_url
      end

      it 'logs the correct attempts event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with({ limiter_context: 'multi-session' })

        get :show
      end
    end

    context 'when the user is proofing rate limited' do
      before do
        RateLimiter.new(
          user: subject.current_user,
          rate_limit_type: :idv_resolution,
        ).increment_to_limited!
      end

      it 'redirects to rate limited url' do
        get :show

        expect(response).to redirect_to idv_session_errors_failure_url
      end

      it 'logs the correct attempts event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with({ limiter_context: 'single-session' })

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

    context 'for an aamva request' do
      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      let(:document_capture_session) do
        DocumentCaptureSession.create(user:)
      end

      let(:success) { true }
      let(:errors) { {} }
      let(:exception) { nil }
      let(:vendor_name) { :aamva }

      let(:async_state) do
        # Here we're trying to match the store to redis -> read from redis flow this data travels
        result = Proofing::Resolution::ResultAdjudicator.new(
          state_id_result: Proofing::StateIdResult.new(
            success: success,
            errors: errors,
            exception: exception,
            vendor_name: vendor_name,
            transaction_id: 'abc123',
            verified_attributes: [],
          ),
          device_profiling_result: Proofing::DdpResult.new(success: true),
          ipp_enrollment_in_progress: false,
          residential_resolution_result: Proofing::Resolution::Result.new(success: true),
          resolution_result: Proofing::Resolution::Result.new(success: true),
          same_address_as_id: true,
          should_proof_state_id: true,
        )

        document_capture_session.create_proofing_session

        document_capture_session.store_proofing_result(result.adjudicated_result.to_h)

        document_capture_session.load_proofing_result
      end

      context 'when aamva processes the request normally' do
        it 'redirect to phone confirmation url' do
          put :show
          expect(response).to redirect_to idv_phone_url
        end

        it 'logs an event with analytics_id set' do
          put :show

          expect(@analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(**analytics_args, success: true, analytics_id: 'Doc Auth'),
          )
        end

        it 'records the cost as billable' do
          expect { put :show }.to change { SpCost.where(cost_type: 'aamva').count }.by(1)
        end
      end

      context 'when aamva returns success: false but no exception' do
        let(:success) { false }

        it 'logs a cost' do
          expect { put :show }.to change { SpCost.where(cost_type: 'aamva').count }.by(1)
        end
      end

      context 'when the jurisdiction is unsupported' do
        let(:success) { true }
        let(:vendor_name) { 'UnsupportedJurisdiction' }

        it 'does not consider the request billable' do
          expect { put :show }.to_not change { SpCost.where(cost_type: 'aamva').count }
        end
      end

      context 'when aamva returns an exception' do
        let(:success) { false }
        let(:exception) { Proofing::Aamva::VerificationError.new('ExceptionId: 0001') }

        it 'redirects user to warning' do
          put :show
          expect(response).to redirect_to idv_session_errors_state_id_warning_url
        end

        it 'logs an event' do
          put :show

          expect(@analytics).to have_logged_event(
            'IdV: doc auth warning visited',
            step_name: 'verify_info',
            remaining_attempts: kind_of(Numeric),
          )
        end

        it 'does not log a cost' do
          expect { put :show }.to change { SpCost.where(cost_type: 'aamva').count }.by(0)
        end
      end
    end
  end

  describe '#update' do
    it 'logs the correct analytics event' do
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

      expect(subject.idv_session.pii_from_doc[:uuid_prefix]).to eq app_id
    end

    it 'updates DocAuthLog verify_submit_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { put :update }.to(
        change { doc_auth_log.reload.verify_submit_count }.from(0).to(1),
      )
    end

    context 'when the user is ssn rate limited' do
      before do
        RateLimiter.new(
          target: Pii::Fingerprinter.fingerprint(
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          ),
          rate_limit_type: :proof_ssn,
        ).increment_to_limited!
      end

      it 'redirects to ssn failure url' do
        put :update

        expect(response).to redirect_to idv_session_errors_ssn_failure_url
      end

      it 'logs the correct attempts event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with({ limiter_context: 'multi-session' })

        put :update
      end
    end

    context 'when the user is proofing rate limited' do
      before do
        RateLimiter.new(
          user: subject.current_user,
          rate_limit_type: :idv_resolution,
        ).increment_to_limited!
      end

      it 'redirects to rate limited url' do
        put :update

        expect(response).to redirect_to idv_session_errors_failure_url
      end

      it 'logs the correct attempts event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with({ limiter_context: 'single-session' })

        put :update
      end
    end
  end
end

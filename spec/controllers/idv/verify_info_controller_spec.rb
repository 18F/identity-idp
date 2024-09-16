require 'rails_helper'

RSpec.describe Idv::VerifyInfoController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:analytics_hash) do
    {
      analytics_id: 'Doc Auth',
      flow_path: 'standard',
      step: 'verify',
    }
  end

  before do
    stub_sign_in(user)
    stub_up_to(:ssn, idv_session: subject.idv_session)
    stub_analytics
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::VerifyInfoController.step_info).to be_valid
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
  end

  describe '#show' do
    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(
        'IdV: doc auth verify visited',
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          step: 'verify',
        },
      )
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
        subject.idv_session.pii_from_doc = subject.idv_session.pii_from_doc.with(address2: 'APT 3E')
        get :show

        expect(response.body).to have_content(t('idv.form.address2'))
      end

      it 'No address2 in PII, still shows address line 2 input' do
        subject.idv_session.pii_from_doc = subject.idv_session.pii_from_doc.with(address2: nil)

        get :show

        expect(response.body).to have_content(t('idv.form.address2'))
      end
    end

    context 'when the user has already verified their info' do
      it 'renders show' do
        stub_up_to(:verify_info, idv_session: subject.idv_session)

        get :show

        expect(response).to render_template :show
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

        expect(@analytics).to have_logged_event('Rate Limit Reached', limiter_type: :proof_ssn)
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

        expect(@analytics).to have_logged_event('Rate Limit Reached', limiter_type: :idv_resolution)
      end
    end

    context 'when proofing_device_profiling is enabled' do
      let(:threatmetrix_client_id) { 'threatmetrix_client' }
      let(:review_status) { 'pass' }
      let(:idv_result) do
        {
          context: {
            stages: {
              threatmetrix: {
                transaction_id: 1,
                review_status: review_status,
                response_body: {
                  client: threatmetrix_client_id,
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

      before do
        controller.
          idv_session.verify_info_step_document_capture_session_uuid = document_capture_session.uuid
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
      end

      context 'when idv_session is missing threatmetrix_session_id' do
        before do
          controller.idv_session.threatmetrix_session_id = nil
          get :show
        end

        it 'redirects back to the SSN step' do
          expect(response).to redirect_to(idv_ssn_url)
        end
      end

      context 'when threatmetrix response is Pass' do
        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('pass')
        end

        # we use the client name for some error tracking, so make sure
        # it gets through to the analytics event log.
        it 'logs the analytics event, including the client' do
          get :show

          expect(@analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(
              proofing_results: hash_including(
                context: hash_including(
                  stages: hash_including(
                    threatmetrix: hash_including(
                      response_body: hash_including(
                        client: threatmetrix_client_id,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        end
      end

      context 'when threatmetrix response is No Result' do
        let(:review_status) { nil }

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to be_nil
        end
      end

      context 'when threatmetrix response is Reject' do
        let(:review_status) { 'reject' }

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('reject')
        end
      end

      context 'when threatmetrix response is Review' do
        let(:review_status) { 'review' }

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('review')
        end
      end
    end

    context 'when proofing_device_profiling is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:disabled)
      end

      context 'when idv_session is missing threatmetrix_session_id' do
        before do
          controller.idv_session.threatmetrix_session_id = nil
          get :show
        end

        it 'does not redirect back to the SSN step' do
          expect(response).not_to redirect_to(idv_ssn_url)
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
        adjudicated_result = Proofing::Resolution::ResultAdjudicator.new(
          state_id_result: Proofing::StateIdResult.new(
            success: success,
            errors: errors,
            exception: exception,
            vendor_name: vendor_name,
            transaction_id: 'abc123',
            verified_attributes: [],
          ),
          device_profiling_result: Proofing::DdpResult.new(success: true),
          ipp_enrollment_in_progress: true,
          residential_resolution_result: Proofing::Resolution::Result.new(success: true),
          resolution_result: Proofing::Resolution::Result.new(success: true),
          same_address_as_id: true,
          should_proof_state_id: true,
        ).adjudicated_result.to_h

        document_capture_session.create_proofing_session

        document_capture_session.store_proofing_result(adjudicated_result)

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
            hash_including(
              {
                analytics_id: 'Doc Auth',
                flow_path: 'standard',
                step: 'verify',
              },
            ),
          )
        end
      end

      context 'when aamva returns success: false but no exception' do
        let(:success) { false }

        it 'redirects to the warning URL' do
          put :show
          expect(response).to redirect_to(idv_session_errors_warning_url)
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
            remaining_submit_attempts: kind_of(Numeric),
          )
        end
      end
    end

    context 'when the resolution proofing job has not completed' do
      let(:async_state) do
        ProofingSessionAsyncResult.new(status: ProofingSessionAsyncResult::IN_PROGRESS)
      end

      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      it 'renders the wait template' do
        get :show

        expect(response).to render_template 'shared/wait'
        expect(@analytics).to have_logged_event(:idv_doc_auth_verify_polling_wait_visited)
      end
    end

    context 'when the reolution proofing job result is missing' do
      let(:async_state) do
        ProofingSessionAsyncResult.new(status: ProofingSessionAsyncResult::MISSING)
      end

      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      it 'renders a timeout error' do
        get :show

        expect(response).to render_template :show
        expect(controller.flash[:error]).to eq(I18n.t('idv.failure.timeout'))
        expect(@analytics).to have_logged_event('IdV: proofing resolution result missing')
      end
    end
  end

  describe '#update' do
    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update
    end

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
      sp_session = { issuer: sp.issuer, vtr: ['C1'] }
      allow(controller).to receive(:sp_session).and_return(sp_session)

      expect(Idv::Agent).to receive(:new).with(
        hash_including(
          ssn: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          consent_given_at: controller.idv_session.idv_consent_given_at,
          **Idp::Constants::MOCK_IDV_APPLICANT,
        ),
      ).and_call_original

      put :update
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
    end
  end
end

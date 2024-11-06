require 'rails_helper'

RSpec.describe Idv::InPerson::VerifyInfoController do
  let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.dup }
  let(:flow_session) do
    { pii_from_user: pii_from_user }
  end

  let(:user) { create(:user, :with_phone, with: { phone: '+1 (415) 555-0130' }) }
  let(:service_provider) { create(:service_provider) }

  before do
    stub_sign_in(user)
    subject.idv_session.flow_path = 'standard'
    subject.idv_session.ssn = Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID[:ssn]
    subject.idv_session.idv_consent_given_at = Time.zone.now.to_s
    subject.user_session['idv/in_person'] = flow_session
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::InPerson::VerifyInfoController.step_info).to be_valid
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

    it 'confirms ssn step complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_ssn_step_complete,
      )
    end

    it 'confirms idv/in_person data is present' do
      expect(subject).to have_actions(
        :before,
        :confirm_pii_data_present,
      )
    end
  end

  before do
    stub_analytics
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
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          step: 'verify',
        },
      )
    end

    context 'when the user is rate limited' do
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

    context 'when done' do
      let(:review_status) { 'review' }
      let(:async_state) { instance_double(ProofingSessionAsyncResult) }
      let(:adjudicated_result) do
        {
          context: {
            stages: {
              threatmetrix: {
                transaction_id: 1,
                review_status: review_status,
                response_body: {
                  session_id: 'threatmetrix_session_id',
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

      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
        allow(async_state).to receive(:done?).and_return(true)
        allow(async_state).to receive(:result).and_return(adjudicated_result)
      end

      it 'logs proofing results with analytics_id' do
        get :show

        expect(@analytics).to have_logged_event(
          'IdV: doc auth verify proofing results',
          hash_including(
            {
              success: true,
              analytics_id: 'In Person Proofing',
              flow_path: 'standard',
              step: 'verify',
            },
          ),
        )
        expect(@analytics).to have_logged_event(
          :idv_threatmetrix_response_body,
          response_body: {
            session_id: 'threatmetrix_session_id',
            tmx_summary_reason_code: ['Identity_Negative_History'],
          },
        )
      end

      it 'logs the edit distance between SSNs' do
        controller.idv_session.ssn = Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn]
        controller.idv_session.previous_ssn = '900-66-1256'

        get :show

        expect(@analytics).to have_logged_event(
          'IdV: doc auth verify proofing results',
          hash_including(
            previous_ssn_edit_distance: 2,
          ),
        )
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

    context 'when the resolution proofing job result is missing' do
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

    context 'when idv/in_person data is present' do
      before do
        subject.user_session['idv/in_person'] = flow_session
      end

      it 'renders the show template without errors' do
        get :show

        expect(response).to render_template :show
      end
    end

    context 'when idv/in_person data is missing' do
      before do
        subject.user_session['idv/in_person'] = {}
      end

      it 'redirects to idv_path' do
        get :show
        expect(response).to redirect_to(idv_path)
      end
    end
  end

  describe '#update' do
    it 'redirects to the expected page' do
      put :update

      expect(response).to redirect_to idv_in_person_verify_info_url
    end

    let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.dup }
    let(:enrollment) { InPersonEnrollment.new }
    before do
      allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    end

    it 'sets ssn on pii_from_user' do
      expect(Idv::Agent).to receive(:new).with(
        hash_including(
          ssn: Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID[:ssn],
          consent_given_at: subject.idv_session.idv_consent_given_at,
        ),
      ).and_call_original

      put :update
    end

    context 'a user does not have an establishing in person enrollment associated with them' do
      before do
        allow(user).to receive(:establishing_in_person_enrollment).and_return(nil)
      end

      it 'indicates to the IDV agent that an IPP enrollment is not in progress' do
        expect_any_instance_of(Idv::Agent).to receive(:proof_resolution).
          with(
            kind_of(DocumentCaptureSession),
            trace_id: subject.send(:amzn_trace_id),
            threatmetrix_session_id: nil,
            user_id: anything,
            request_ip: request.remote_ip,
            ipp_enrollment_in_progress: false,
          )

        put :update
      end
    end

    context 'a user does have an establishing in person enrollment associated with them' do
      it 'indicates to the IDV agent that ipp_enrollment_in_progress is enabled' do
        expect_any_instance_of(Idv::Agent).to receive(:proof_resolution).with(
          kind_of(DocumentCaptureSession),
          trace_id: anything,
          threatmetrix_session_id: anything,
          user_id: anything,
          request_ip: anything,
          ipp_enrollment_in_progress: true,
        )

        put :update
      end

      it 'captures state id address fields in the pii' do
        expect(Idv::Agent).to receive(:new).with(
          Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.merge(
            consent_given_at: subject.idv_session.idv_consent_given_at,
            best_effort_phone_number_for_socure: {
              source: :mfa,
              phone: '+1 415-555-0130',
            },
          ),
        ).and_call_original
        put :update
      end
    end

    it 'passes the X-Amzn-Trace-Id to the proofer' do
      expect_any_instance_of(Idv::Agent).to receive(:proof_resolution).
        with(
          kind_of(DocumentCaptureSession),
          trace_id: subject.send(:amzn_trace_id),
          threatmetrix_session_id: nil,
          user_id: anything,
          request_ip: request.remote_ip,
          ipp_enrollment_in_progress: true,
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

    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update
    end
  end
end

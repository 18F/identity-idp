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
        :confirm_profile_not_already_confirmed,
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
        expect(step.send(:idv_agent)).not_to receive(:proof_resolution)

        put :update
      end

      context 'when pii_from_user is blank' do
        it 'marks step as incomplete' do
          flow_session[:pii_from_user] = {}
          flow_session['Idv::Steps::InPerson::SsnStep'] = true
          result = put :update
          expect(flow_session['Idv::Steps::InPerson::SsnStep']).to eq nil
          expect(result.success?).to eq false
        end
      end

      context 'when different users use the same SSN within the same timeframe' do
        let(:user2) { create(:user) }
        let(:flow2) do
        end
        let(:controller2) do
          instance_double(
            'controller',
            analytics: FakeAnalytics.new,
            current_user: user2,
            request: request,
            session: { sp: { issuer: service_provider.issuer } },
            url_options: {},
          )
        end

        def build_step(controller)
          flow = Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person').tap do |flow|
            flow_session = { pii_from_user: pii }
          end

          Idv::Steps::InPerson::VerifyStep.new(flow)
        end

        before do
          allow(IdentityConfig.store).to receive(:proof_ssn_max_attempts).and_return(3)
          allow(IdentityConfig.store).to receive(:proof_ssn_max_attempt_window_in_minutes).
            and_return(10)
        end

        def redirect(step)
          step.instance_variable_get(:@flow).instance_variable_get(:@redirect)
        end

        it 'throttles them all' do
          expect(build_step(controller).call).to be_kind_of(ApplicationJob)
          expect(build_step(controller2).call).to be_kind_of(ApplicationJob)

          step = build_step(controller)
          expect(put :update).to be_nil, 'does not enqueue a job'
          expect(redirect(step)).to eq(idv_session_errors_ssn_failure_url)

          step2 = build_step(controller2)
          expect(step2.call).to be_nil, 'does not enqueue a job'
          expect(redirect(step2)).to eq(idv_session_errors_ssn_failure_url)
        end
      end

      it 'updates proofing component vendor' do
        put :update

        expect(user.proofing_component.document_check).to eq Idp::Constants::Vendors::USPS
      end
    end
  end
end

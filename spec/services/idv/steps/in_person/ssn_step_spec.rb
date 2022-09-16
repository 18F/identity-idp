require 'rails_helper'

describe Idv::Steps::InPerson::SsnStep do
  let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }
  let(:params) { { doc_auth: { ssn: ssn } } }
  let(:session) { { sp: { issuer: service_provider.issuer } } }
  let(:user) { build(:user) }
  let(:service_provider_device_profiling_enabled) { true }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
      device_profiling_enabled: service_provider_device_profiling_enabled,
    )
  end
  let(:attempts_api) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:threatmetrix_session_id) { nil }
  let(:controller) do
    instance_double(
      'controller',
      session: session,
      params: params,
      current_user: user,
      analytics: FakeAnalytics.new,
      irs_attempts_api_tracker: attempts_api,
    )
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person').tap do |flow|
      flow.flow_session = {
        pii_from_user: {},
      }
    end
  end

  subject(:step) do
    Idv::Steps::InPerson::SsnStep.new(flow)
  end

  describe '#call' do
    it 'merges ssn into pii session value' do
      step.call

      expect(flow.flow_session[:pii_from_user][:ssn]).to eq(ssn)
    end

    context 'with existing session applicant' do
      let(:session) { super().merge(idv: { 'applicant' => {} }) }

      it 'clears applicant' do
        step.call

        expect(session[:idv]['applicant']).to be_blank
      end
    end

    context 'with service provider device profiling enabled' do
      let(:service_provider_device_profiling_enabled) { true }

      context 'with proofing device profiling collecting enabled' do
        it 'adds a session id to flow session' do
          allow(IdentityConfig.store).
            to receive(:proofing_device_profiling_collecting_enabled).
            and_return(true)
          step.extra_view_variables

          expect(flow.flow_session[:threatmetrix_session_id]).to_not eq(nil)
        end

        it 'does not change threatmetrix_session_id when updating ssn' do
          allow(IdentityConfig.store).
            to receive(:proofing_device_profiling_collecting_enabled).
            and_return(true)
          step.call
          session_id = flow.flow_session[:threatmetrix_session_id]
          step.extra_view_variables
          expect(flow.flow_session[:threatmetrix_session_id]).to eq(session_id)
        end
      end
    end

    context 'with service provider device profiling disabled' do
      let(:service_provider_device_profiling_enabled) { false }

      context 'with proofing device profiling collecting enabled' do
        it 'does not add a session id to flow session' do
          allow(IdentityConfig.store).
            to receive(:proofing_device_profiling_collecting_enabled).and_return(true)
          step.extra_view_variables

          expect(flow.flow_session[:threatmetrix_session_id]).to be_nil
        end

        it 'does not change threatmetrix_session_id when updating ssn' do
          allow(IdentityConfig.store).
            to receive(:proofing_device_profiling_collecting_enabled).and_return(true)
          step.call
          session_id = flow.flow_session[:threatmetrix_session_id]
          step.extra_view_variables
          expect(flow.flow_session[:threatmetrix_session_id]).to eq(session_id)
        end
      end
    end

    context 'with service provider device profiling enabled' do
      let(:service_provider_device_profiling_enabled) { true }

      context 'with proofing device profiling collecting disabled' do
        it 'still adds a session id to flow session' do
          allow(IdentityConfig.store).
            to receive(:proofing_device_profiling_collecting_enabled).
            and_return(false)
          step.extra_view_variables
          expect(flow.flow_session[:threatmetrix_session_id]).to_not eq(nil)
        end
      end
    end

    context 'with service provider device profiling disabled' do
      let(:service_provider_device_profiling_enabled) { false }

      context 'with proofing device profiling collecting disabled' do
        it 'does not add a session id to flow session' do
          allow(IdentityConfig.store).
            to receive(:proofing_device_profiling_collecting_enabled).and_return(false)
          step.extra_view_variables
          expect(flow.flow_session[:threatmetrix_session_id]).to be_nil
        end
      end
    end
  end
end

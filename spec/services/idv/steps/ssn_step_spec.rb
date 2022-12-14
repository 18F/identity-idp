require 'rails_helper'

describe Idv::Steps::SsnStep do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:params) { { doc_auth: {} } }
  let(:session) { { sp: { issuer: service_provider.issuer } } }
  let(:attempts_api) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end
  let(:controller) do
    instance_double(
      'controller',
      session: session,
      current_user: user,
      params: params,
      analytics: FakeAnalytics.new,
      irs_attempts_api_tracker: attempts_api,
      url_options: {},
      request: double(
        'request',
        headers: {
          'X-Amzn-Trace-Id' => amzn_trace_id,
        },
      ),
    )
  end
  let(:amzn_trace_id) { SecureRandom.uuid }

  let(:pii_from_doc) do
    {
      first_name: Faker::Name.first_name,
    }
  end

  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = {
        pii_from_doc: pii_from_doc,
      }
    end
  end

  subject(:step) do
    Idv::Steps::SsnStep.new(flow)
  end

  describe '#call' do
    context 'with valid ssn' do
      let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }
      let(:params) { { doc_auth: { ssn: ssn } } }

      it 'merges ssn into pii session value' do
        step.call

        expect(flow.flow_session[:pii_from_doc][:ssn]).to eq(ssn)
      end

      it 'logs attempts api event' do
        expect(attempts_api).to receive(:idv_ssn_submitted).with(
          ssn: ssn,
        )
        step.call
      end

      context 'with existing session applicant' do
        let(:session) { super().merge(idv: { 'applicant' => {} }) }

        it 'clears applicant' do
          step.call

          expect(session[:idv]['applicant']).to be_blank
        end
      end

      it 'adds a threatmetrix session id to flow session' do
        step.extra_view_variables
        expect(flow.flow_session[:threatmetrix_session_id]).to_not eq(nil)
      end

      it 'does not change threatmetrix_session_id when updating ssn' do
        step.call
        session_id = flow.flow_session[:threatmetrix_session_id]
        step.extra_view_variables
        expect(flow.flow_session[:threatmetrix_session_id]).to eq(session_id)
      end
    end

    context 'when pii_from_doc is not present' do
      let(:flow) do
        Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
          flow.flow_session = { 'Idv::Steps::DocumentCaptureStep' => true }
        end
      end

      it 'marks previous step as incomplete' do
        expect(flow.flow_session['Idv::Steps::DocumentCaptureStep']).to eq true
        result = step.call
        expect(flow.flow_session['Idv::Steps::DocumentCaptureStep']).to eq nil
        expect(result.success?).to eq false
      end
    end
  end
end

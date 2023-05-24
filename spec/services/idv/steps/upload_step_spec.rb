require 'rails_helper'

describe Idv::Steps::UploadStep do
  context 'with combined hybrid handoff enabled' do
    let(:user) { build(:user) }

    let(:service_provider) do
      create(
        :service_provider,
        issuer: 'http://sp.example.com',
        app_id: '123',
      )
    end

    let(:request) do
      double(
        'request',
        remote_ip: Faker::Internet.ip_v4_address,
        headers: { 'X-Amzn-Trace-Id' => amzn_trace_id },
      )
    end

    let(:params) do
      ActionController::Parameters.new(
        {
          doc_auth: { phone: '(201) 555-1212' },
          combined: true,
        },
      )
    end

    let(:controller) do
      instance_double(
        'controller',
        session: { sp: { issuer: service_provider.issuer } },
        params: params,
        current_user: user,
        current_sp: service_provider,
        analytics: FakeAnalytics.new,
        url_options: {},
        request: request,
      )
    end

    let(:amzn_trace_id) { SecureRandom.uuid }

    let(:pii_from_doc) do
      {
        ssn: '123-45-6789',
        first_name: 'bob',
      }
    end

    let(:flow) do
      Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
        flow.flow_session = { pii_from_doc: pii_from_doc }
      end
    end

    subject(:step) do
      Idv::Steps::UploadStep.new(flow)
    end

    describe '#extra_view_variables' do
      it 'includes form' do
        expect(step.extra_view_variables).to include(
          {
            idv_phone_form: be_an_instance_of(Idv::PhoneForm),
          },
        )
      end
    end

    describe 'the return value from #call' do
      let(:response) { step.call }

      it 'includes the telephony response' do
        expect(response.extra[:telephony_response]).to eq(
          {
            errors: {},
            message_id: 'fake-message-id',
            request_id: 'fake-message-request-id',
            success: true,
          },
        )
      end
    end

    describe '#link_for_send_link' do
      subject(:link) { step.link_for_send_link document_capture_session_uuid }
      let(:document_capture_session_uuid) { SecureRandom.uuid }

      it 'generates a link to the hybrid mobile doc auth entry controller' do
        expect(link).to eql(
          Rails.application.routes.url_helpers.idv_hybrid_mobile_entry_url(
            params: {
              'document-capture-session': document_capture_session_uuid,
            },
          ),
        )
      end
    end
  end
end

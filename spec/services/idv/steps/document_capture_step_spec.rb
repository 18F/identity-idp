require 'rails_helper'

describe Idv::Steps::DocumentCaptureStep do
  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      current_sp: service_provider,
      current_user: user,
      params: params,
    )
  end

  let(:document_capture_session) do
    DocumentCaptureSession.create(user: user)
  end
  let(:document_capture_session_uuid) { document_capture_session.uuid }

  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = { document_capture_session_uuid: document_capture_session_uuid }
    end
  end

  subject(:step) do
    Idv::Steps::DocumentCaptureStep.new(flow)
  end


  describe '#call' do
    before do
      allow(FeatureManagement).to receive(:document_capture_async_uploads_enabled?).
        and_return(document_capture_async_uploads_enabled)
    end

    context 'in a synchronous context' do
      let(:document_capture_async_uploads_enabled) { false }

      let(:params) do
        {
          doc_auth: {
            front_image: DocAuthImageFixtures.document_front_image_multipart,
            back_image: DocAuthImageFixtures.document_back_image_multipart,
            selfie_image: DocAuthImageFixtures.document_face_image_multipart,
          }
        }
      end

      it 'works' do
        result = nil
        expect { result = step.call }.to(change { ProofingComponent.find_by(user: user) })

        expect(result.success?).to eq(true)
      end
    end

    context 'in an async context' do
      let(:document_capture_async_uploads_enabled) { true }
      let(:params) { { doc_auth: {} } }

      before do
        document_capture_session.store_result_from_response(
          DocAuth::Response.new(
            success: true,
            errors: {},
            pii_from_doc: Idp::Constants::MOCK_IDV_APPLICANT,
          ),
        )
      end

      it 'works' do
        result = nil
        expect { result = step.call }.to(change { ProofingComponent.find_by(user: user) })

        expect(result).to be_nil
      end
    end
  end
end

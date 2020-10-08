require 'rails_helper'

describe Idv::CaptureDocStatusController do
  let(:user) { build(:user) }
  let(:document_capture_step_enabled) { false }

  before do
    stub_sign_in(user) if user

    allow(FeatureManagement).to receive(:document_capture_step_enabled?).
      and_return(document_capture_step_enabled)
  end

  describe '#show' do
    context 'when unauthenticated' do
      let(:user) { nil }

      it 'redirects to the root url' do
        get :show

        expect(response).to redirect_to root_url
      end
    end

    context 'when document capture step is disabled' do
      let(:document_capture_step_enabled) { false }
      let(:doc_capture) { nil }

      before do
        allow(DocCapture).to receive(:find_by).and_return(doc_capture)
      end

      context 'when session does not exist' do
        let(:doc_capture) { nil }

        it 'returns unauthorized' do
          get :show

          expect(response.status).to eq(401)
          expect(response.body).to eq('Unauthorized')
        end
      end

      context 'when result is pending' do
        let(:doc_capture) do
          DocCapture.create(
            user_id: user.id,
            request_token: SecureRandom.uuid,
            requested_at: Time.zone.now,
          )
        end

        it 'returns pending result' do
          get :show

          expect(response.status).to eq(202)
          expect(response.body).to eq('Pending')
        end
      end

      context 'when capture is complete' do
        let(:doc_capture) do
          DocCapture.create(
            user_id: user.id,
            request_token: SecureRandom.uuid,
            requested_at: Time.zone.now,
            acuant_token: SecureRandom.uuid,
          )
        end

        it 'returns success' do
          get :show

          expect(response.status).to eq(200)
          expect(response.body).to eq('Complete')
        end
      end
    end

    context 'when document capture step is enabled' do
      let(:document_capture_step_enabled) { true }
      let(:document_capture_session) { DocumentCaptureSession.create! }
      let(:flow_session) { { document_capture_session_uuid: document_capture_session.uuid } }

      before do
        allow_any_instance_of(Flow::BaseFlow).to receive(:flow_session).and_return(flow_session)
        controller.user_session['idv/doc_auth'] = flow_session
      end

      context 'when session does not exist' do
        let(:flow_session) { {} }

        it 'returns unauthorized' do
          get :show

          expect(response.status).to eq(401)
          expect(response.body).to eq('Unauthorized')
        end
      end

      context 'when result is pending' do
        it 'returns pending result' do
          get :show

          expect(response.status).to eq(202)
          expect(response.body).to eq('Pending')
        end
      end

      context 'when capture failed' do
        before do
          allow(EncryptedRedisStructStorage).to receive(:load).and_return(
            DocumentCaptureSessionResult.new(
              id: SecureRandom.uuid,
              success: false,
              pii: {},
            ),
          )
        end

        it 'returns unauthorized' do
          get :show

          expect(response.status).to eq(401)
          expect(response.body).to eq('Unauthorized')
        end
      end

      context 'when capture succeeded' do
        before do
          allow(EncryptedRedisStructStorage).to receive(:load).and_return(
            DocumentCaptureSessionResult.new(
              id: SecureRandom.uuid,
              success: true,
              pii: {},
            ),
          )
        end

        it 'returns success' do
          get :show

          expect(response.status).to eq(200)
          expect(response.body).to eq('Complete')
        end
      end
    end
  end
end

require 'rails_helper'

describe Idv::CaptureDocStatusController do
  let(:user) { build(:user) }

  before do
    stub_sign_in(user) if user
  end

  describe '#show' do
    let(:document_capture_session) { DocumentCaptureSession.create!(user: user) }
    let(:flow_session) { { document_capture_session_uuid: document_capture_session.uuid } }

    before do
      allow_any_instance_of(Flow::BaseFlow).to receive(:flow_session).and_return(flow_session)
      controller.user_session['idv/doc_auth'] = flow_session if user
    end

    context 'when unauthenticated' do
      let(:user) { nil }

      it 'redirects to the root url' do
        get :show

        expect(response).to redirect_to root_url
      end
    end

    context 'when flow session expires' do
      let(:flow_session) { nil }

      it 'returns unauthorized' do
        get :show

        expect(response.status).to eq(401)
      end
    end

    context 'when session does not exist' do
      let(:flow_session) { {} }

      it 'returns unauthorized' do
        get :show

        expect(response.status).to eq(401)
      end
    end

    context 'when the user cancelled document capture on their phone' do
      before do
        document_capture_session.cancelled_at = Time.zone.now
        document_capture_session.save!
      end

      it 'returns cancelled' do
        get :show

        expect(response.status).to eq(410)
      end
    end

    context 'when the user is throttled' do
      before do
        Throttle.new(throttle_type: :idv_doc_auth, user: user).increment_to_throttled!
      end

      it 'returns throttled with redirect' do
        get :show

        expect(response.status).to eq(429)
        expect(JSON.parse(response.body)).to include('redirect')
      end
    end

    context 'when result is pending' do
      it 'returns pending result' do
        get :show

        expect(response.status).to eq(202)
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
      end
    end

    context 'when capture succeeded with barcode attention' do
      let(:result) do
        DocumentCaptureSessionResult.new(
          id: SecureRandom.uuid,
          success: true,
          pii: {},
          attention_with_barcode: true,
        )
      end

      before do
        allow(EncryptedRedisStructStorage).to receive(:load).and_return(result)
      end

      context 'when barcode attention result is pending confirmation' do
        before do
          document_capture_session.update(ocr_confirmation_pending: true)
        end

        it 'returns pending result' do
          get :show

          expect(response.status).to eq(202)
        end

        it 'assigns flow session values as having received attention result' do
          get :show

          expect(flow_session[:had_barcode_attention_error]).to eq(true)
        end
      end

      context 'when result is confirmed' do
        before do
          document_capture_session.update(ocr_confirmation_pending: false)
        end

        it 'returns success' do
          get :show

          expect(response.status).to eq(200)
        end

        it 'assigns flow session values as having received attention result' do
          get :show

          expect(flow_session[:had_barcode_attention_error]).to eq(true)
        end
      end

      context 'when user receives a second result that is not the attention result' do
        let(:result) do
          DocumentCaptureSessionResult.new(
            id: SecureRandom.uuid,
            success: true,
            pii: {},
            attention_with_barcode: false,
          )
        end

        before do
          flow_session[:had_barcode_attention_error] = true
          document_capture_session.update(ocr_confirmation_pending: false)
        end

        it 'assigns flow session values as not having received attention result' do
          get :show

          expect(flow_session[:had_barcode_attention_error]).to eq(false)
        end
      end

      context 'when loaded result expires but session was already marked with attention result' do
        let(:result) { nil }
        let(:flow_session) do
          {
            document_capture_session_uuid: document_capture_session.uuid,
            had_barcode_attention_error: true,
          }
        end

        context 'when barcode attention result is pending confirmation' do
          before do
            document_capture_session.update(ocr_confirmation_pending: true)
          end

          it 'returns pending result' do
            get :show

            expect(response.status).to eq(202)
          end

          it 'assigns flow session values as having received attention result' do
            get :show

            expect(flow_session[:had_barcode_attention_error]).to eq(true)
          end
        end

        context 'when result is confirmed' do
          before do
            document_capture_session.update(ocr_confirmation_pending: false)
          end

          it 'returns success' do
            get :show

            expect(response.status).to eq(200)
          end

          it 'assigns flow session values as having received attention result' do
            get :show

            expect(flow_session[:had_barcode_attention_error]).to eq(true)
          end
        end
      end
    end
  end
end

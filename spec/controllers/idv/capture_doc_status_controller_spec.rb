require 'rails_helper'

RSpec.describe Idv::CaptureDocStatusController do
  let(:user) { build(:user) }

  let(:doc_auth_response) do
    DocAuth::Response.new(
      success: true,
      pii_from_doc: {
        first_name: 'Testy',
        last_name: 'Testerson',
      },
    )
  end

  let(:failed_doc_auth_response) do
    DocAuth::Response.new(
      success: false,
    )
  end

  let(:barcode_attention_auth_response) do
    DocAuth::Response.new(
      success: true,
      pii_from_doc: {
        first_name: 'Testy',
        last_name: 'Testerson',
      },
      attention_with_barcode: true,
    )
  end

  before do
    stub_sign_in(user) if user
  end

  describe '#show' do
    let(:document_capture_session) { DocumentCaptureSession.create!(user:) }

    before do
      subject.idv_session.document_capture_session_uuid = document_capture_session.uuid if user
    end

    context 'when unauthenticated' do
      let(:user) { nil }

      it 'redirects to the root url' do
        get :show

        expect(response).to redirect_to root_url
      end
    end

    context 'when session does not exist' do
      it 'returns unauthorized' do
        subject.idv_session.document_capture_session_uuid = nil
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

    context 'when the user is rate limited' do
      before do
        RateLimiter.new(rate_limit_type: :idv_doc_auth, user:).increment_to_limited!
      end

      it 'returns rate_limited with redirect' do
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

    context 'when capture succeeded' do
      before do
        document_capture_session.store_result_from_response(doc_auth_response)
      end

      it 'returns success' do
        get :show

        expect(response.status).to eq(200)
      end
    end

    context 'when capture succeeded with barcode attention' do
      before do
        document_capture_session.store_result_from_response(barcode_attention_auth_response)
      end

      context 'when barcode attention result is pending confirmation' do
        before do
          document_capture_session.update(ocr_confirmation_pending: true)
        end

        it 'returns pending result' do
          get :show

          expect(response.status).to eq(202)
        end

        it 'assigns idv session values as having received attention result' do
          get :show

          expect(subject.idv_session.had_barcode_attention_error).to eq(true)
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

        it 'assigns idv session values as having received attention result' do
          get :show

          expect(subject.idv_session.had_barcode_attention_error).to eq(true)
        end
      end

      context 'when user receives a second result that is not the attention result' do
        before do
          subject.idv_session.had_barcode_attention_error = true
          document_capture_session.update(ocr_confirmation_pending: false)

          document_capture_session.store_result_from_response(doc_auth_response)
        end

        it 'assigns idv session values as not having received attention result' do
          get :show

          expect(subject.idv_session.had_barcode_attention_error).to eq(false)
        end
      end

      context 'when loaded result expires but session was already marked with attention result' do
        let(:result) { nil }

        before do
          subject.idv_session.had_barcode_attention_error = true
        end

        context 'when barcode attention result is pending confirmation' do
          before do
            document_capture_session.update(ocr_confirmation_pending: true)
          end

          it 'returns pending result' do
            get :show

            expect(response.status).to eq(202)
          end

          it 'assigns idv session values as having received attention result' do
            get :show

            expect(subject.idv_session.had_barcode_attention_error).to eq(true)
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

          it 'assigns idv session values as having received attention result' do
            get :show

            expect(subject.idv_session.had_barcode_attention_error).to eq(true)
          end
        end
      end
    end

    context 'when user opted for in-person proofing' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        create(:in_person_enrollment, :establishing, user:, profile: nil)
      end

      it 'returns success with redirect' do
        get :show

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to include('redirect' => idv_in_person_url)
      end
    end
  end
end

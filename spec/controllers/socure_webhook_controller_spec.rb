# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureWebhookController do
  describe 'POST /api/webhooks/socure/event' do
    let(:user) { create(:user) }
    let(:socure_docv_transaction_token) { 'dummy_docv_transaction_token' }
    let(:document_capture_session) do
      DocumentCaptureSession.create(user:).tap do |dcs|
        dcs.socure_docv_transaction_token = socure_docv_transaction_token
      end
    end
    let(:rate_limiter) { RateLimiter.new(rate_limit_type: :idv_doc_auth, user: user) }
    let(:socure_secret_key) { 'this-is-a-secret' }
    let(:socure_secret_key_queue) { ['this-is-an-old-secret', 'this-is-an-older-secret'] }
    let(:socure_enabled) { true }
    let(:webhook_body) do
      {
        event: {
          created: '2020-01-01T00:00:00Z',
          customerUserId: '123',
          eventType: 'TEST_WEBHOOK',
          referenceId: 'abc',
          data: {
            documentData: {
              dob: '2000-01-01',
              firstName: 'First',
              lastName: 'Last',
              address: '123 Main St, Baltimore, MD',
            },
          },
        },
      }
    end
    let(:document_uploaded_webhook_body) do
      {
        eventGroup: 'DocvNotification',
        reason: 'DOCUMENTS_UPLOADED',
        event: {
          created: '2020-01-01T00:00:00Z',
          docvTransactionToken: socure_docv_transaction_token,
          eventType: 'DOCUMENTS_UPLOADED',
          message: 'Documents Upload Successful',
          referenceId: user.id,
        },
      }
    end

    before do
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key).
        and_return(socure_secret_key)
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key_queue).
        and_return(socure_secret_key_queue)
      allow(IdentityConfig.store).to receive(:socure_enabled).
        and_return(socure_enabled)

      stub_analytics
    end

    context 'webhook authentication' do
      it 'returns OK and logs an event with a correct secret key and body' do
        request.headers['Authorization'] = socure_secret_key
        post :create, params: webhook_body

        expect(response).to have_http_status(:ok)
        expect(@analytics).to have_logged_event(
          :idv_doc_auth_socure_webhook_received,
          created_at: '2020-01-01T00:00:00Z',
          customer_user_id: '123',
          event_type: 'TEST_WEBHOOK',
          reference_id: 'abc',
          user_id: '123',
        )
      end

      it 'returns OK with an older secret key' do
        request.headers['Authorization'] = socure_secret_key_queue.last
        post :create, params: webhook_body

        expect(response).to have_http_status(:ok)
      end

      it 'returns unauthorized with a bad secret key' do
        request.headers['Authorization'] = 'ABC123'
        post :create, params: webhook_body

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized with no secret key' do
        post :create, params: webhook_body

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns bad request with no event in the body' do
        request.headers['Authorization'] = socure_secret_key
        post :create, params: {}

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when DOCUMENTS_UPLOADED event received' do
      let(:webhook_body) do
        {
          id: 'a8202f22-7331-483b-a76a-546f68da062d',
          origId: '45ac9531-60ae-4bc7-805e-f7823e4e5545',
          eventGroup: 'DocvNotification',
          reason: 'DOCUMENTS_UPLOADED',
          environmentName: 'Production',
          event: {
            created: '2024-08-07T21:18:19.949Z',
            customerUserId: '111-222-333',
            docVTransactionToken: '45ac9531-60ae-4bc7-805e-f7823e4e5545',
            eventType: 'DOCUMENTS_UPLOADED',
            message: 'Documents Upload Successful',
            referenceId: '45ac9531-60ae-4bc7-805e-f7823e4e5545',
            userId: '444-555-666',
          },
        }
      end

      it 'returns OK and logs an event with a correct secret key and body' do
        request.headers['Authorization'] = socure_secret_key
        post :create, params: document_uploaded_webhook_body
        expect(response).to have_http_status(:ok)
        expect(@analytics).to have_logged_event(
          :idv_doc_auth_socure_webhook_received,
          created_at: document_uploaded_webhook_body[:event][:created],
          event_type: document_uploaded_webhook_body[:event][:eventType],
          reference_id: document_uploaded_webhook_body[:event][:referenceId].to_s,
        )
      end

      context 'when document capture session exists' do
        let(:user) { create(:user) }
        let(:document_capture_session) do
          DocumentCaptureSession.create(user:).tap do |dcs|
            dcs.socure_docv_transaction_token = '45ac9531-60ae-4bc7-805e-f7823e4e5545'
          end
        end

        before do
          request.headers['Authorization'] = socure_secret_key
          allow(DocumentCaptureSession).to receive(:find_by).
            and_return(document_capture_session)
          allow(SocureDocvResultsJob).to receive(:perform_later)
          allow(RateLimiter).to receive(:new).with(
            {
              user: user,
              rate_limit_type: :idv_doc_auth,
            },
          ).and_return(rate_limiter)
        end

        it 'increments rate limiter of correct user' do
          expect(rate_limiter.attempts).to eq 0
          post :create, params: document_uploaded_webhook_body
          expect(rate_limiter.attempts).to eq 1
          post :create, params: document_uploaded_webhook_body
          expect(rate_limiter.attempts).to eq 2
        end

        it 'enqueues a SocureDocvResultsJob' do
          post :create, params: webhook_body

          expect(SocureDocvResultsJob).to have_received(:perform_later).
            with(document_capture_session_uuid: document_capture_session.uuid)
        end
      end

      context 'when document capture session does not exist' do
        before do
          allow(NewRelic::Agent).to receive(:notice_error)
        end

        it 'logs an error with NewRelic' do
          request.headers['Authorization'] = socure_secret_key_queue.last
          post :create, params: webhook_body

          expect(NewRelic::Agent).to have_received(:notice_error)
        end
      end
    end

    context 'when socure webhook disabled' do
      let(:socure_enabled) { false }

      it 'the webhook route does not exist' do
        request.headers['Authorization'] = socure_secret_key
        post :create, params: webhook_body

        expect(response).to be_not_found
      end
    end

    context 'when SESSION_COMPLETE event received' do
      let(:docv_transaction_token) { '45ac9531-60ae-4bc7-805e-f7823e4e5547' }
      let(:webhook_body) do
        {
          id: 'a8202f22-7331-483b-a76a-546f68da062d',
          origId: '45ac9531-60ae-4bc7-805e-f7823e4e5545',
          eventGroup: 'DocvNotification',
          reason: 'SESSION_COMPLETE',
          environmentName: 'Production',
          event: {
            created: '2024-08-07T21:18:19.949Z',
            customerUserId: '111-222-333',
            docVTransactionToken: docv_transaction_token,
            eventType: 'SESSION_COMPLETE',
            message: 'Session Complete',
            referenceId: '45ac9531-60ae-4bc7-805e-f7823e4e5545',
          },
        }
      end

      context 'when document capture session exists' do
        let(:user) { create(:user) }
        let(:document_capture_session) do
          DocumentCaptureSession.create(user:).tap do |dcs|
            dcs.socure_docv_transaction_token = docv_transaction_token
          end
        end

        before do
          request.headers['Authorization'] = socure_secret_key
          allow(DocumentCaptureSession).to receive(:find_by).
            and_return(document_capture_session)
          allow(SocureDocvResultsJob).to receive(:perform_later)
          allow(RateLimiter).to receive(:new).with(
            {
              user: user,
              rate_limit_type: :idv_doc_auth,
            },
          ).and_return(rate_limiter)
        end

        it 'does not increment rate limiter of user' do
          expect(rate_limiter.attempts).to eq 0
          post :create, params: webhook_body
          expect(rate_limiter.attempts).to eq 0
          post :create, params: webhook_body
          expect(rate_limiter.attempts).to eq 0
        end

        it 'does not enqueue a SocureDocvResultsJob' do
          post :create, params: webhook_body

          expect(SocureDocvResultsJob).not_to have_received(:perform_later).
            with(document_capture_session_uuid: document_capture_session.uuid)
        end
      end
    end
  end
end

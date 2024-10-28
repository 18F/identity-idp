# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureWebhookController do
  describe 'POST /api/webhooks/socure/event' do
    let(:socure_secret_key) { 'this-is-a-secret' }
    let(:socure_secret_key_queue) { ['this-is-an-old-secret', 'this-is-an-older-secret'] }
    let(:socure_enabled) { true }
    let(:event_type) { 'TEST_WEBHOOK' }
    let(:webhook_body) do
      {
        event: {
          created: '2020-01-01T00:00:00Z',
          customerUserId: '123',
          eventType: event_type,
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

    before do
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key).
        and_return(socure_secret_key)
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key_queue).
        and_return(socure_secret_key_queue)
      allow(IdentityConfig.store).to receive(:socure_enabled).
        and_return(socure_enabled)
      allow(NewRelic::Agent).to receive(:notice_error)

      stub_analytics
    end

    it 'returns OK and logs an event with a correct secret key and body' do
      request.headers['Authorization'] = socure_secret_key
      post :create, params: webhook_body

      expect(response).to have_http_status(:ok)
      expect(@analytics).to have_logged_event(
        :idv_doc_auth_socure_webhook_received,
        created_at: '2020-01-01T00:00:00Z',
        customer_user_id: '123',
        event_type: event_type,
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

    context 'when DOCUMENTS_UPLOADED event received' do
      let(:event_type) { 'DOCUMENTS_UPLOADED' }

      context 'when document capture session does not exist' do
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
  end
end

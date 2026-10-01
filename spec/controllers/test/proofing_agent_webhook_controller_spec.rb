require 'rails_helper'

RSpec.describe Test::ProofingAgentWebhookController do
  after { ProofingAgent::MockWebhookReceiver.clear! }

  describe '#create' do
    let(:payload) do
      { success: true, reason: nil, transaction_id: 'transaction-id-123' }
    end

    before do
      request.headers['Content-Type'] = 'application/json'
      request.headers['Authorization'] = 'Bearer test-secret'
      request.headers['X-Correlation-ID'] = 'correlation-id-456'
    end

    it 'responds 200 and records the webhook' do
      post :create, body: payload.to_json

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq('received' => true)

      webhooks = ProofingAgent::MockWebhookReceiver.webhooks
      expect(webhooks.length).to eq(1)
      expect(webhooks.first.body).to eq(
        'success' => true,
        'reason' => nil,
        'transaction_id' => 'transaction-id-123',
      )
      expect(webhooks.first.authorization).to eq('Bearer test-secret')
      expect(webhooks.first.correlation_id).to eq('correlation-id-456')
    end

    it 'stores the raw body when it is not valid JSON' do
      post :create, body: 'not-json'

      expect(response.status).to eq(200)
      expect(ProofingAgent::MockWebhookReceiver.webhooks.first.body).to eq('not-json')
    end

    it '404s in production' do
      allow(Rails.env).to receive(:production?).and_return(true)

      post :create, body: payload.to_json

      expect(response.status).to eq(404)
      expect(ProofingAgent::MockWebhookReceiver.webhooks).to be_empty
    end
  end

  describe '#index' do
    it 'returns the recorded webhooks, most recent first' do
      ProofingAgent::MockWebhookReceiver.record(
        body: { 'transaction_id' => 'first' },
        authorization: nil,
        correlation_id: nil,
        content_type: 'application/json',
        received_at: '2026-09-30T00:00:00Z',
      )
      ProofingAgent::MockWebhookReceiver.record(
        body: { 'transaction_id' => 'second' },
        authorization: nil,
        correlation_id: nil,
        content_type: 'application/json',
        received_at: '2026-09-30T00:00:01Z',
      )

      get :index

      transaction_ids = response.parsed_body['webhooks'].map { |w| w['body']['transaction_id'] }
      expect(transaction_ids).to eq(%w[second first])
    end

    it '404s in production' do
      allow(Rails.env).to receive(:production?).and_return(true)

      get :index

      expect(response.status).to eq(404)
    end
  end

  describe '#destroy' do
    it 'clears the recorded webhooks' do
      ProofingAgent::MockWebhookReceiver.record(
        body: {},
        authorization: nil,
        correlation_id: nil,
        content_type: 'application/json',
        received_at: '2026-09-30T00:00:00Z',
      )

      delete :destroy

      expect(response.status).to eq(200)
      expect(ProofingAgent::MockWebhookReceiver.webhooks).to be_empty
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProofingAgent::WebhookCaller do
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:proofing_agent' }
  let(:webhook_url) { 'https://agent.example.gov/results' }
  let(:document_capture_session) { create(:document_capture_session, issuer:) }
  let(:analytics) { FakeAnalytics.new }
  let(:caller) do
    described_class.new(
      success: true,
      reason: nil,
      transaction_id: document_capture_session.uuid,
      correlation_id: 'correlation-id',
      analytics_attributes: { proofing_agent: 'agent-1', proofing_components: {} },
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:idv_proofing_agent_config).and_return(
      [{ 'issuer' => issuer, 'webhook' => { 'url' => webhook_url } }],
    )
    allow(caller).to receive(:analytics).and_return(analytics)
  end

  describe '#call' do
    it 'posts the result to the configured webhook' do
      request = stub_request(:post, webhook_url).to_return(status: 200, body: '')

      caller.call

      expect(request).to have_been_requested
      expect(analytics).to have_logged_event(
        :idv_proofing_agent_webhook,
        hash_including(success: true),
      )
    end

    context 'when the configured webhook points at a private address' do
      let(:webhook_url) { 'https://10.0.0.5/results' }

      it 'sends nothing and reports the refusal' do
        caller.call

        expect(a_request(:post, webhook_url)).not_to have_been_made
        expect(analytics).to have_logged_event(
          :idv_proofing_agent_webhook,
          hash_including(success: false, response: 'webhook url refused: private_address'),
        )
      end
    end
  end
end

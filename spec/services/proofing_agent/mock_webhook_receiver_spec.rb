require 'rails_helper'

RSpec.describe ProofingAgent::MockWebhookReceiver do
  after { described_class.clear! }

  def record(transaction_id)
    described_class.record(
      body: { 'transaction_id' => transaction_id },
      authorization: 'Bearer test-secret',
      correlation_id: 'correlation-id',
      content_type: 'application/json',
      received_at: '2026-09-30T00:00:00Z',
    )
  end

  describe '.record' do
    it 'stores webhooks most recent first' do
      record('first')
      record('second')

      expect(described_class.webhooks.map { |w| w.body['transaction_id'] }).to eq(%w[second first])
    end

    it 'keeps only the most recent MAX_WEBHOOKS entries' do
      (described_class::MAX_WEBHOOKS + 5).times { |i| record("txn-#{i}") }

      expect(described_class.webhooks.length).to eq(described_class::MAX_WEBHOOKS)
      # The oldest entries are dropped; the most recent is kept at the front.
      last_index = described_class::MAX_WEBHOOKS + 4
      expect(described_class.webhooks.first.body['transaction_id']).to eq("txn-#{last_index}")
    end
  end

  describe '.clear!' do
    it 'removes all stored webhooks' do
      record('first')

      described_class.clear!

      expect(described_class.webhooks).to be_empty
    end
  end
end

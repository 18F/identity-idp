# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureDocvRepeatWebhookJob do
  let(:job) { described_class.new }
  let(:headers) do
    {
      Authorization: 'auhtoriztion-header',
      'Content-Type': 'application/json',
    }
  end
  let(:endpoint) { 'https://example.test/endpoint' }
  let(:body) do
    {
      event: {
        created: '2020-01-01T00:00:00Z',
        customerUserId: 'customer-user-id',
        eventType: 'REPEATED_EVENT',
        docvTransactionToken: 'rando-token',
        referenceId: 'reference-id',
      },
    }
  end

  before do
    stub_request(:post, endpoint)
      .with(body:, headers:)
  end

  describe '#perform' do
    subject(:perform) do
      job.perform(body:, headers:, endpoint:)
    end

    it 'repeats the webhook' do
      expect(Faraday).to receive(:new).and_call_original
      expect(NewRelic::Agent).not_to receive(:notice_error)

      perform
    end

    context 'failed endpoint repeat' do
      before do
        allow_any_instance_of(DocAuth::Socure::WebhookRepeater)
          .to receive(:send_http_post_request).with(endpoint).and_raise('uh-oh')
      end

      it 'sends message to New Relic' do
        expect(NewRelic::Agent).to receive(:notice_error) do |*args|
          expect(args.first).to be_a_kind_of(RuntimeError)
          expect(args.last).to eq(
            {
              custom_params: {
                event: 'Failed to repeat webhook',
                endpoint:,
                body:,
              },
            },
          )
        end

        perform
      end
    end
  end
end

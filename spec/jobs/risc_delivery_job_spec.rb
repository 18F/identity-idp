require 'rails_helper'

RSpec.describe RiscDeliveryJob do
  describe '#perform' do
    let(:push_notification_url) { 'https://push.example.gov' }
    let(:jwt) { JWT.encode({ foo: 'bar' }, 'a') }
    let(:event_type) { PushNotification::IdentifierRecycledEvent::EVENT_TYPE }
    let(:issuer) { 'issuer1' }
    let(:transport) { 'ruby_worker' }

    let(:job) { RiscDeliveryJob.new }
    subject(:perform) do
      job.perform(
        push_notification_url: push_notification_url,
        jwt: jwt,
        event_type: event_type,
        issuer: issuer,
      )
    end

    it 'POSTs the jwt to the given URL' do
      req = stub_request(:post, push_notification_url).
        with(
          body: jwt,
          headers: {
            'Content-Type' => 'application/secevent+jwt',
            'Accept' => 'application/json',
          },
        )

      perform

      expect(req).to have_been_requested
    end

    context 'network errors' do
      before do
        stub_request(:post, push_notification_url).to_timeout
      end

      context 'when performed inline' do
        it 'warns on timeouts' do
          expect(Rails.logger).to receive(:warn) do |msg|
            payload = JSON.parse(msg, symbolize_names: true)

            expect(payload[:event]).to eq('http_push_error')
            expect(payload[:transport]).to eq('direct')
          end

          expect { perform }.to_not raise_error
        end
      end

      context 'when performed in a worker' do
        before do
          allow(job).to receive(:queue_adapter).
            and_return(ActiveJob::QueueAdapters::GoodJobAdapter.new)
        end

        it 'raises on timeouts (and retries via ActiveJob)' do
          expect(Rails.logger).to_not receive(:warn)

          expect { perform }.to raise_error(Faraday::ConnectionFailed)
        end
      end
    end
  end
end

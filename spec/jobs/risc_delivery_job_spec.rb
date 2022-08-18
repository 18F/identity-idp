require 'rails_helper'

RSpec.describe RiscDeliveryJob do
  around do |ex|
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
    ex.run
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
  end

  describe '#perform' do
    let(:push_notification_url) { 'https://push.example.gov' }
    let(:jwt) { JWT.encode({ foo: 'bar' }, 'a') }
    let(:event_type) { PushNotification::IdentifierRecycledEvent::EVENT_TYPE }
    let(:issuer) { 'issuer1' }
    let(:now) { 5.hours.ago }

    let(:job) { RiscDeliveryJob.new }
    subject(:perform) do
      job.perform(
        push_notification_url: push_notification_url,
        jwt: jwt,
        event_type: event_type,
        issuer: issuer,
        now: now,
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

    context 'SSL network errors' do
      before do
        stub_request(:post, push_notification_url).to_raise(Faraday::SSLError)
      end

      context 'when performed inline' do
        it 'prints warning' do
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

        it 'raises and retries via ActiveJob' do
          expect(Rails.logger).to_not receive(:warn)

          expect { perform }.to raise_error(Faraday::SSLError)
        end
      end
    end

    context 'Errno::ECONNREFUSED error' do
      before do
        # stub_request().to_raise wraps this in Faraday::ConnectionFailed, but
        # in actual usage, the original error is unwrapped
        expect(job.faraday).to receive(:post).and_raise(Errno::ECONNREFUSED)
      end

      context 'when performed inline' do
        it 'prints a warning' do
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

        it 'raises and retries via ActiveJob' do
          expect(Rails.logger).to_not receive(:warn)

          expect { perform }.to raise_error(Errno::ECONNREFUSED)
        end
      end
    end

    context 'non-200 response' do
      before do
        stub_request(:post, push_notification_url).to_return(status: 403)
      end

      context 'when performed inline' do
        it 'prints a warning' do
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

        it 'prints a warning' do
          expect(Rails.logger).to receive(:warn) do |msg|
            payload = JSON.parse(msg, symbolize_names: true)

            expect(payload[:event]).to eq('http_push_error')
            expect(payload[:transport]).to eq('async')
          end

          expect { perform }.to_not raise_error
        end
      end
    end

    context 'slow network errors' do
      before do
        stub_request(:post, push_notification_url).to_timeout
      end

      context 'when performed inline' do
        it 'prints warning' do
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

        it 'raises and retries via ActiveJob' do
          expect(Rails.logger).to_not receive(:warn)

          expect { perform }.to raise_error(Faraday::ConnectionFailed)
        end
      end
    end

    context 'rate limiting' do
      before do
        REDIS_POOL.with { |r| r.set(job.rate_limiter(push_notification_url).build_key(now), 9999) }
      end

      context 'when performed inline' do
        it 'warns on limit hit' do
          expect(Rails.logger).to receive(:warn) do |msg|
            payload = JSON.parse(msg, symbolize_names: true)

            expect(payload[:event]).to eq('http_push_rate_limit')
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

        it 'raises on rate limit errors (and retries via ActiveJob)' do
          expect(Rails.logger).to_not receive(:warn)

          expect { perform }.to raise_error(RedisRateLimiter::LimitError)
        end
      end

      context 'when the rate limit is overridden' do
        before do
          allow(IdentityConfig.store).to receive(:risc_notifications_rate_limit_overrides).
            and_return({ push_notification_url => { 'max_requests' => 1e6, 'interval' => 500 } })
        end

        it 'allows the request' do
          req = stub_request(:post, push_notification_url)
          perform

          expect(req).to have_been_requested
        end
      end
    end
  end

  describe '.warning_error_classes' do
    it 'is all the network errors and rate limiting errors' do
      expect(described_class.warning_error_classes).to match_array(
        [*described_class::NETWORK_ERRORS, RedisRateLimiter::LimitError],
      )
    end
  end
end

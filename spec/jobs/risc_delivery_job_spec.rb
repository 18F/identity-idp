require 'rails_helper'

RSpec.describe RiscDeliveryJob do
  around do |ex|
    REDIS_THROTTLE_POOL.with { |client| client.flushdb }
    ex.run
    REDIS_THROTTLE_POOL.with { |client| client.flushdb }
  end

  describe '#perform' do
    let(:event_type) { PushNotification::IdentifierRecycledEvent::EVENT_TYPE }
    let(:issuer) { 'issuer1' }
    let(:job) { RiscDeliveryJob.new }
    let(:job_analytics) { FakeAnalytics.new }
    let(:jwt) { JWT.encode({ foo: 'bar' }, 'a') }
    let(:now) { 5.hours.ago }
    let(:push_notification_url) { 'https://push.example.gov' }

    let(:risc_event_payload) do
      {
        client_id: issuer,
        error: nil,
        event_type: event_type,
        status: nil,
        success: false,
        transport: 'direct',
      }
    end

    subject(:perform) do
      job.perform(
        push_notification_url: push_notification_url,
        jwt: jwt,
        event_type: event_type,
        issuer: issuer,
        now: now,
      )
    end

    before do
      allow(job).to receive(:analytics).and_return(job_analytics)
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
      expect(job_analytics).to have_logged_event(
        :risc_security_event_pushed,
        risc_event_payload.merge(
          success: true,
          status: 200,
        ),
      )
    end

    context 'SSL network errors' do
      before do
        stub_request(:post, push_notification_url).to_raise(Faraday::SSLError)
      end

      context 'when performed inline' do
        it 'logs an event' do
          expect { perform }.to_not raise_error

          expect(job_analytics).to have_logged_event(
            :risc_security_event_pushed,
            risc_event_payload.merge(error: 'Exception from WebMock'),
          )
        end
      end

      context 'when performed in a worker' do
        before do
          allow(job).to receive(:queue_adapter).
            and_return(ActiveJob::QueueAdapters::GoodJobAdapter.new)
        end

        it 'raises and retries via ActiveJob' do
          expect { perform }.to raise_error(Faraday::SSLError)
        end

        context 'it has already failed twice' do
          before do
            allow(job).to receive(:executions).and_return 2
          end

          it 'logs an event' do
            expect { perform }.to_not raise_error

            expect(job_analytics).to have_logged_event(
              :risc_security_event_pushed,
              risc_event_payload.merge(
                error: 'Exception from WebMock',
                transport: 'async',
              ),
            )
          end
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
        it 'logs an event' do
          expect { perform }.to_not raise_error
          expect(job_analytics).to have_logged_event(
            :risc_security_event_pushed,
            risc_event_payload.merge(error: 'Connection refused'),
          )
        end
      end

      context 'when performed in a worker' do
        before do
          allow(job).to receive(:queue_adapter).
            and_return(ActiveJob::QueueAdapters::GoodJobAdapter.new)
        end

        it 'raises and retries via ActiveJob' do
          expect { perform }.to raise_error(Errno::ECONNREFUSED)
        end

        context 'it has already failed twice' do
          before do
            allow(job).to receive(:executions).and_return 2
          end

          it 'logs an event' do
            expect { perform }.to_not raise_error

            expect(job_analytics).to have_logged_event(
              :risc_security_event_pushed,
              risc_event_payload.merge(
                error: 'Connection refused',
                transport: 'async',
              ),
            )
          end
        end
      end
    end

    context 'non-200 response' do
      before do
        stub_request(:post, push_notification_url).to_return(status: 403)
      end

      context 'when performed inline' do
        it 'logs an event' do
          expect { perform }.to_not raise_error
          expect(job_analytics).to have_logged_event(
            :risc_security_event_pushed,
            risc_event_payload.merge(
              error: 'http_push_error',
              status: 403,
            ),
          )
        end
      end

      context 'when performed in a worker' do
        before do
          allow(job).to receive(:queue_adapter).
            and_return(ActiveJob::QueueAdapters::GoodJobAdapter.new)
        end

        it 'logs an event' do
          expect { perform }.to_not raise_error
          expect(job_analytics).to have_logged_event(
            :risc_security_event_pushed,
            risc_event_payload.merge(
              error: 'http_push_error',
              status: 403,
              transport: 'async',
            ),
          )
        end

        context 'it has already failed twice' do
          before do
            allow(job).to receive(:executions).and_return 2
          end

          it 'logs an event' do
            expect { perform }.to_not raise_error

            expect(job_analytics).to have_logged_event(
              :risc_security_event_pushed,
              risc_event_payload.merge(
                error: 'http_push_error',
                status: 403,
                transport: 'async',
              ),
            )
          end
        end
      end
    end

    context 'slow network errors' do
      before do
        stub_request(:post, push_notification_url).to_timeout
      end

      context 'when performed inline' do
        it 'logs an event' do
          expect { perform }.to_not raise_error
          expect(job_analytics).to have_logged_event(
            :risc_security_event_pushed,
            risc_event_payload.merge(
              error: 'execution expired',
            ),
          )
        end
      end

      context 'when performed in a worker' do
        before do
          allow(job).to receive(:queue_adapter).
            and_return(ActiveJob::QueueAdapters::GoodJobAdapter.new)
        end

        it 'raises and retries via ActiveJob' do
          expect { perform }.to raise_error(Faraday::ConnectionFailed)
        end

        context 'it has already failed twice' do
          before do
            allow(job).to receive(:executions).and_return 2
          end

          it 'logs an event' do
            expect { perform }.to_not raise_error

            expect(job_analytics).to have_logged_event(
              :risc_security_event_pushed,
              risc_event_payload.merge(
                error: 'execution expired',
                transport: 'async',
              ),
            )
          end
        end
      end
    end

    context 'rate limiting' do
      before do
        REDIS_THROTTLE_POOL.with do |redis|
          redis.set(job.rate_limiter(push_notification_url).build_key(now), 9999)
        end
      end

      context 'when performed inline' do
        it 'logs an event on limit hit' do
          expect { perform }.to_not raise_error
          expect(job_analytics).to have_logged_event(
            :risc_security_event_pushed,
            risc_event_payload.merge(
              error: 'rate limit for push-notification-https://push.example.gov has maxed out',
            ),
          )
        end
      end

      context 'when performed in a worker' do
        before do
          allow(job).to receive(:queue_adapter).
            and_return(ActiveJob::QueueAdapters::GoodJobAdapter.new)
        end

        it 'raises on rate limit errors (and retries via ActiveJob)' do
          expect { perform }.to raise_error(RedisRateLimiter::LimitError)
        end

        context 'it has already failed ten times' do
          before do
            allow(job).to receive(:executions).and_return 10
          end

          it 'logs an event' do
            expect { perform }.to_not raise_error

            expect(job_analytics).to have_logged_event(
              :risc_security_event_pushed,
              risc_event_payload.merge(
                error: 'rate limit for push-notification-https://push.example.gov has maxed out',
                transport: 'async',
              ),
            )
          end
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
          expect(job_analytics).to have_logged_event(
            :risc_security_event_pushed,
            risc_event_payload.merge(
              success: true,
              status: 200,
              transport: 'direct',
            ),
          )
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

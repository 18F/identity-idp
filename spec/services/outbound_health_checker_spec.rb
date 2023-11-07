require 'rails_helper'

RSpec.describe OutboundHealthChecker do
  before do
    Rails.cache.clear
  end

  describe '#check' do
    subject(:check) { OutboundHealthChecker.check }

    context 'bad config' do
      before do
        expect(IdentityConfig.store).to receive(:outbound_connection_check_url).and_return('')
      end

      it 'is not healthy' do
        expect(check).to_not be_healthy
        expect(check.result).to eq('missing outbound_connection_check_url')
      end
    end

    context 'successful connection to endpoint' do
      before do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url).
          to_return(status:)
      end

      context '200 response from endpoint' do
        let(:status) { 200 }

        it 'is healthy' do
          expect(check).to be_healthy
          expect(check.result).to eq(
            url: IdentityConfig.store.outbound_connection_check_url,
            status:,
          )
        end
      end

      context '300 response from endpoint' do
        let(:status) { 300 }

        it 'is healthy' do
          expect(check).to be_healthy
          expect(check.result).to eq(
            url: IdentityConfig.store.outbound_connection_check_url,
            status:,
          )
        end
      end

      context '400 response from endpoint' do
        let(:status) { 400 }

        it 'is not healthy' do
          expect(check).to_not be_healthy
        end

        it 'notifies newrelic' do
          expect(NewRelic::Agent).to receive(:notice_error)

          check
        end
      end

      context '500 response from endpoint' do
        let(:status) { 500 }

        it 'is not healthy' do
          expect(check).to_not be_healthy
        end

        it 'notifies newrelic' do
          expect(NewRelic::Agent).to receive(:notice_error)

          check
        end
      end
    end

    context 'timeout from endpoint' do
      it 'retries and is healthy if the second request succeeds' do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url).
          to_timeout.then.to_return(status: 200)

        expect(check).to be_healthy
      end

      it 'is not healthy after 2 retries' do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url).to_timeout

        expect(check).to_not be_healthy
      end

      it 'notifies newrelic' do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url).to_timeout

        expect(NewRelic::Agent).to receive(:notice_error)

        check
      end
    end

    context 'connection fails to endpoint' do
      before do
        allow(IdentityConfig.store).to receive(:outbound_connection_check_retry_count).and_return(2)
      end

      it 'retries and is healthy if the second request succeeds' do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url).
          to_raise(Faraday::ConnectionFailed).then.to_return(status: 200)

        expect(check).to be_healthy
      end

      it 'is not healthy after 2 retries' do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url).
          to_raise(Faraday::ConnectionFailed)

        expect(check).to_not be_healthy
      end

      it 'notifies newrelic' do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url).
          to_raise(Faraday::ConnectionFailed)

        expect(NewRelic::Agent).to receive(:notice_error)

        check
      end
    end
  end
end

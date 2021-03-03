require 'rails_helper'

RSpec.describe OutboundHealthChecker do
  describe '#check' do
    subject(:check) { OutboundHealthChecker.check }

    context 'bad config' do
      before do
        expect(AppConfig.env).to receive(:outbound_connection_check_url).and_return('')
      end

      it 'is not healthy' do
        expect(check).to_not be_healthy
        expect(check.result).to eq('missing outbound_connection_check_url')
      end
    end

    context 'successful connection to endpoint' do
      before do
        stub_request(:get, AppConfig.env.outbound_connection_check_url).
          to_return(status: status)
      end

      context '200 response from endpoint' do
        let(:status) { 200 }

        it 'is healthy' do
          expect(check).to be_healthy
          expect(check.result).to eq(
            url: AppConfig.env.outbound_connection_check_url,
            status: status,
          )
        end
      end

      context '300 response from endpoint' do
        let(:status) { 300 }

        it 'is healthy' do
          expect(check).to be_healthy
          expect(check.result).to eq(
            url: AppConfig.env.outbound_connection_check_url,
            status: status,
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
      before do
        stub_request(:get, AppConfig.env.outbound_connection_check_url).to_timeout
      end

      it 'is not healthy' do
        expect(check).to_not be_healthy
      end

      it 'notifies newrelic' do
        expect(NewRelic::Agent).to receive(:notice_error)

        check
      end
    end
  end
end
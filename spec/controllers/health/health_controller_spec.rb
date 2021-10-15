require 'rails_helper'

RSpec.describe Health::HealthController do
  describe '#index' do
    context 'when all checked resources are healthy' do
      it 'returns a successful JSON response' do
        allow(DatabaseHealthChecker).to receive(:simple_query).and_return('foo')
        allow(AccountResetHealthChecker).to receive(:check).
          and_return(HealthCheckSummary.new(healthy: true, result: 'foo'))

        get :index
        json = JSON.parse(response.body, symbolize_names: true)

        expect(response.status).to eq(200)
        expect(json[:healthy]).to eq(true)
        expect(json[:statuses][:database][:healthy]).to eq(true)
        expect(json[:statuses][:account_reset][:healthy]).to eq(true)
      end
    end

    context 'when one resource is unhealthy' do
      it 'returns an unsuccessful JSON response' do
        allow(DatabaseHealthChecker).to receive(:simple_query).
          and_raise(RuntimeError.new('canceling statement due to statement timeout'))
        allow(AccountResetHealthChecker).to receive(:check).
          and_return(HealthCheckSummary.new(healthy: true, result: 'foo'))

        get :index
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:healthy]).to eq(false)
        expect(json[:statuses][:database][:result]).
          to include('canceling statement due to statement timeout')
        expect(json[:statuses][:account_reset][:healthy]).to eq(true)
        expect(response.status).to eq(500)
      end
    end

    context 'all resources are unhealthy' do
      it 'returns an unsuccessful JSON response' do
        allow(DatabaseHealthChecker).to receive(:simple_query).
          and_raise(RuntimeError.new('canceling statement due to statement timeout'))
        allow(AccountResetHealthChecker).to receive(:check).
          and_return(HealthCheckSummary.new(healthy: false, result: 'foo'))

        get :index
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:healthy]).to eq(false)
        expect(json[:statuses][:database][:result]).
          to include('canceling statement due to statement timeout')
        expect(json[:statuses][:account_reset][:healthy]).to eq(false)
        expect(response.status).to eq(500)
      end
    end
  end
end

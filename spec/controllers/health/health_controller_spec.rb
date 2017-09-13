require 'rails_helper'

RSpec.describe Health::HealthController do
  describe '#index' do
    subject(:action) { get :index }

    before do
      allow(WorkerHealthChecker).to receive(:check).
        and_return(WorkerHealthChecker::Summary.new(statuses))
    end

    let(:statuses) { [WorkerHealthChecker::Status.new('voice', 0.minutes.ago, true)] }

    context 'when all checked resources are healthy' do
      it 'is a 200' do
        action

        expect(response.status).to eq(200)
      end

      it 'renders the result' do
        action

        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:healthy]).to eq(true)
        expect(json[:statuses][:workers][:all_healthy]).to eq(true)
        expect(json[:statuses][:database][:healthy]).to eq(true)
      end
    end

    context 'when one resource is unhealthy' do
      before do
        expect(DatabaseHealthChecker).to receive(:simple_query).
          and_raise(RuntimeError.new('canceling statement due to statement timeout'))
      end

      it 'is a 500' do
        action

        expect(response.status).to eq(500)
      end

      it 'renders the error' do
        action

        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:healthy]).to eq(false)
        expect(json[:statuses][:database][:result]).
          to include('canceling statement due to statement timeout')
      end
    end
  end
end

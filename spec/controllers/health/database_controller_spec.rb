require 'rails_helper'

RSpec.describe Health::DatabaseController do
  describe '#index' do
    subject(:action) { get :index }

    context 'when the database is healthy' do
      it 'is a 200' do
        action

        expect(response.status).to eq(200)
      end

      it 'renders the result' do
        action

        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:healthy]).to eq(true)
        expect(json[:result]).to eq([1])
      end
    end

    context 'when the database is unhealthy' do
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
        expect(json[:result]).to include('canceling statement due to statement timeout')
      end
    end
  end
end

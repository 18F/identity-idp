require 'rails_helper'

RSpec.describe Health::OutboundController do
  before do
    Rails.cache.clear
  end

  describe '#index' do
    subject(:action) { get :index }

    context 'when the outbound connections are healthy' do
      before do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url)
          .to_return(status: 200)
      end

      it 'is a 200' do
        action

        expect(response.status).to eq(200)
      end

      it 'renders the result' do
        action

        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:healthy]).to eq(true)
        expect(json[:result]).to eq(
          status: 200,
          url: IdentityConfig.store.outbound_connection_check_url,
        )
      end
    end

    context 'when the outbound connections are uhealthy' do
      before do
        stub_request(:head, IdentityConfig.store.outbound_connection_check_url).to_timeout
      end

      it 'is a 500' do
        action

        expect(response.status).to eq(500)
      end

      it 'renders the error' do
        action

        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:healthy]).to eq(false)
        expect(json[:result]).to include('execution expired')
      end
    end
  end
end

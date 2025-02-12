require 'rails_helper'

RSpec.describe Api::Attempts::EventsController do
  include Rails.application.routes.url_helpers
  let(:enabled) { false }

  before do
    allow(IdentityConfig.store).to receive(:attempts_api_enabled).and_return(enabled)
  end

  describe '#poll' do
    let(:action) { post :poll }

    context 'when the Attempts API is not enabled' do
      it 'returns 404 not found' do
        expect(action.status).to eq(404)
      end
    end

    context 'when the Attempts API is enabled' do
      let(:enabled) { true }
      it 'returns 405 method not allowed' do
        expect(action.status).to eq(405)
      end
    end
  end

  describe 'status' do
    let(:action) { get :status }

    context 'when the Attempts API is not enabled' do
      it 'returns 404 not found' do
        expect(action.status).to eq(404)
      end
    end

    context 'when the Attempts API is enabled' do
      let(:enabled) { true }
      it 'returns a 200' do
        expect(action.status).to eq(200)
      end

      it 'returns the disabled status and reason' do
        body = JSON.parse(action.body, symbolize_names: true)
        expect(body[:status]).to eq('disabled')
        expect(body[:reason]).to eq('not_yet_implemented')
      end
    end
  end
end

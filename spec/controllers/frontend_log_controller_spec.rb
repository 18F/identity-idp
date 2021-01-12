require 'rails_helper'

describe FrontendLogController do
  describe '#create' do
    subject(:action) { post :create, params: params }

    let(:user) { create(:user, :with_phone, with: { phone: '+1 (202) 555-1212' }) }
    let(:event) { 'Custom Event' }
    let(:payload) { { message: 'To be logged...' } }
    let(:params) { { event: event, payload: payload } }
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    context 'user is signed in' do
      before do
        sign_in user
        stub_analytics
      end

      it 'succeeds' do
        expect(@analytics).to receive(:track_event).
          with("Frontend: #{event}", payload)

        action

        expect(response).to have_http_status(:ok)
        expect(json[:success]).to eq(true)
      end

      context 'missing a parameter' do
        it 'rejects a request without specifying event' do
          expect(@analytics).not_to receive(:track_event)

          params.delete(:event)
          action

          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
        end

        it 'rejects a request without specifying payload' do
          expect(@analytics).not_to receive(:track_event)

          params.delete(:payload)
          action

          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
        end
      end
    end

    context 'user is not signed in' do
      it 'returns unauthorized' do
        stub_analytics

        expect(@analytics).not_to receive(:track_event)

        action

        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to eq(false)
      end
    end
  end
end

require 'rails_helper'

describe FrontendLogController do
  describe '#create' do
    subject(:action) { post :create, params: params }

    let(:user) { create(:user, :with_phone, with: { phone: '+1 (202) 555-1212' }) }
    let(:params) { { event: 'custom event', payload: { message: 'To be logged...' } } }
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    context 'user is signed in' do

      before do
        sign_in user
      end

      it 'succeeds' do
        action

        expect(response).to have_http_status(:ok)
        expect(json[:success]).to eq(true)
      end

      context 'missing a parameter' do
        it 'rejects a request without specifying event' do
          params.delete(:event)
          action

          # json = JSON.parse(response.body, symbolize_names: true)
          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
        end

        it 'rejects a request without specifying payload' do
          params.delete(:payload)
          action

          # json = JSON.parse(response.body, symbolize_names: true)
          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
        end
      end
    end

    context 'user is not signed in' do
      it 'returns unauthorized' do
        action

        # json = JSON.parse(response.body, symbolize_names: true)
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to eq(false)
      end
    end
  end
end

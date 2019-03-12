require 'rails_helper'

describe ExpiredLettersController do
  describe '#update' do
    context 'with a good auth token' do
      before do
        headers(Figaro.env.expired_letters_auth_token)
      end

      it 'returns ok' do
        headers(Figaro.env.expired_letters_auth_token)
        post :update

        expect(response).to be_ok
      end

      it 'logs the number of notifications sent in the analytics' do
        service = instance_double(SendExpiredLetterNotifications)
        allow(SendExpiredLetterNotifications).to receive(:new).and_return(service)
        allow(service).to receive(:call).and_return(7)

        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::EXPIRED_LETTERS, event: :notifications, count: 7)

        post :update
      end
    end

    context 'with a bad auth token' do
      before do
        headers('foo')
      end

      it 'returns unauthorized' do
        headers('foo')
        post :update

        expect(response.status).to eq 401
      end
    end
  end

  def headers(token)
    request.headers['X-API-AUTH-TOKEN'] = token
  end
end

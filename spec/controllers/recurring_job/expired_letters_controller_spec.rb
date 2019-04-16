require 'rails_helper'

describe RecurringJob::ExpiredLettersController do
  describe '#create' do
    it_behaves_like 'a recurring job controller', Figaro.env.expired_letters_auth_token

    context 'with a good auth token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = Figaro.env.expired_letters_auth_token
      end

      it 'logs the number of notifications sent in the analytics' do
        service = instance_double(SendExpiredLetterNotifications)
        allow(SendExpiredLetterNotifications).to receive(:new).and_return(service)
        allow(service).to receive(:call).and_return(7)

        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::EXPIRED_LETTERS, event: :notifications, count: 7)

        post :create
      end
    end
  end
end

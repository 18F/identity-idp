require 'rails_helper'

describe UndeliverableAddressController do
  describe '#create' do
    context 'with no token' do
      it 'returns unauthorized' do
        post :create

        expect(response.status).to eq 401
      end
    end

    context 'with an invalid token' do
      before do
        headers('foobar')
      end

      it 'returns unauthorized' do
        post :create

        expect(response.status).to eq 401
      end
    end

    context 'with a valid token' do
      before do
        headers(Figaro.env.usps_download_token)
      end

      it 'returns a good status' do
        notifier = instance_double(UndeliverableAddressNotifier)
        expect(notifier).to receive(:call)
        expect(UndeliverableAddressNotifier).to receive(:new).and_return(notifier)

        post :create

        expect(response).to have_http_status(:ok)
      end
    end
  end

  def headers(token)
    request.headers['X-API-AUTH-TOKEN'] = token
  end
end

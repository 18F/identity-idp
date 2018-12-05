require 'rails_helper'

describe UspsUploadController do
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
        headers(Figaro.env.usps_upload_token)
      end

      it 'returns a good status' do
        post :create

        expect(response).to have_http_status(:ok)
      end
    end
  end

  def headers(token)
    request.headers['X-API-AUTH-TOKEN'] = token
  end
end

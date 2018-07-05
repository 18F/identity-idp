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

      context 'on a federal workday' do
        it 'runs the uploader' do
          usps_uploader = instance_double(UspsUploader)
          expect(usps_uploader).to receive(:run)
          expect(UspsUploader).to receive(:new).and_return(usps_uploader)

          post :create

          expect(response).to have_http_status(:ok)
        end
      end

      context 'on a federal holiday' do
        it 'does not run the uploader' do
          expect(controller).to receive(:today).and_return(Date.new(2019, 1, 1))

          expect(UspsUploader).not_to receive(:new)

          post :create

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  def headers(token)
    request.headers['X-USPS-UPLOAD-TOKEN'] = token
  end
end

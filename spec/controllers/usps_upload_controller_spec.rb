require 'rails_helper'

describe UspsUploadController do
  describe '#create' do
    it 'runs the uploader' do
      usps_uploader = instance_double(UspsUploader)
      expect(usps_uploader).to receive(:run)
      expect(UspsUploader).to receive(:new).and_return(usps_uploader)

      post :create

      expect(response).to have_http_status(:ok)
    end

    it 'does not run the upload on a federal holiday' do
      expect(controller).to receive(:today).and_return(Date.new(2019, 1, 1))

      expect(UspsUploader).not_to receive(:new)

      post :create

      expect(response).to have_http_status(:ok)
    end
  end
end

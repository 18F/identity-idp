require 'rails_helper'

describe RecurringJob::UspsUploadController do
  describe '#create' do
    it_behaves_like 'a recurring job controller', Figaro.env.usps_upload_token

    context 'with a valid token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = Figaro.env.usps_upload_token
      end

      context 'on a federal workday' do
        it 'runs the uploader' do
          Timecop.travel Date.new(2018, 7, 3) do
            usps_uploader = instance_double(UspsConfirmationUploader)
            expect(usps_uploader).to receive(:run)
            expect(UspsConfirmationUploader).to receive(:new).and_return(usps_uploader)

            post :create

            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'on a federal holiday' do
        it 'does not run the uploader' do
          Timecop.travel Date.new(2019, 1, 1) do
            expect(UspsConfirmationUploader).not_to receive(:new)

            post :create

            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end
end

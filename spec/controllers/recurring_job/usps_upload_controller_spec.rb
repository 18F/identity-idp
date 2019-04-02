require 'rails_helper'

describe RecurringJob::UspsUploadController do
  describe '#create' do
    let(:usps_uploader) { instance_double(UspsConfirmationUploader) }

    before do
      allow(usps_uploader).to receive(:run)
      allow(UspsConfirmationUploader).to receive(:new).and_return(usps_uploader)
    end

    it_behaves_like 'a recurring job controller', Figaro.env.usps_upload_token

    context 'with a valid token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = Figaro.env.usps_upload_token
      end

      context 'on a federal workday' do
        it 'runs the uploader' do
          Timecop.travel Date.new(2018, 7, 3) do
            post :create

            expect(response).to have_http_status(:ok)
            expect(usps_uploader).to have_received(:run)
          end
        end
      end

      context 'on a federal holiday' do
        it 'does not run the uploader' do
          Timecop.travel Date.new(2019, 1, 1) do
            post :create

            expect(response).to have_http_status(:ok)
            expect(UspsConfirmationUploader).not_to have_received(:new)
            expect(usps_uploader).to_not have_received(:run)
          end
        end
      end
    end
  end
end

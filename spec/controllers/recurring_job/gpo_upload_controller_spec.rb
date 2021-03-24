require 'rails_helper'

describe RecurringJob::GpoUploadController do
  describe '#create' do
    it_behaves_like 'a recurring job controller', AppConfig.env.usps_upload_token

    context 'with a valid token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = AppConfig.env.usps_upload_token
      end

      context 'on a federal workday' do
        it 'runs the uploader' do
          Timecop.travel Date.new(2018, 7, 3) do
            gpo_uploader = instance_double(GpoConfirmationUploader)
            expect(gpo_uploader).to receive(:run)
            expect(GpoConfirmationUploader).to receive(:new).and_return(gpo_uploader)

            post :create

            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'on a federal holiday' do
        it 'does not run the uploader' do
          Timecop.travel Date.new(2019, 1, 1) do
            expect(GpoConfirmationUploader).not_to receive(:new)

            post :create

            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end
end

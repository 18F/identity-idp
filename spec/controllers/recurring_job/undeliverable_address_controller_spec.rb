require 'rails_helper'

describe RecurringJob::UndeliverableAddressController do
  describe '#create' do
    before do
      # Prevent the controller action from actually trying to open an SFTP
      # connection in the shared examples
      allow(Net::SFTP).to receive(:start)
    end

    it_behaves_like 'a recurring job controller', Figaro.env.usps_download_token

    context 'with a valid token' do
      before do
        request.headers['X-API-AUTH-TOKEN'] = Figaro.env.usps_download_token
      end

      it 'returns triggers undeliverable address notifications' do
        notifier = instance_double(UndeliverableAddressNotifier)
        expect(notifier).to receive(:call)
        expect(UndeliverableAddressNotifier).to receive(:new).and_return(notifier)

        post :create

        expect(response).to have_http_status(:ok)
      end
    end
  end
end

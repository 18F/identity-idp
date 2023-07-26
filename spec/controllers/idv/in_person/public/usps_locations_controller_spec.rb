require 'rails_helper'

RSpec.describe Idv::InPerson::Public::UspsLocationsController do
  include Rails.application.routes.url_helpers

  describe '#index' do
    subject(:action) do
      post :index,
           params:
            { address: { address: '87060 Colby Radial, Stephenmouth, OK 73339-7909',
                         zip_code: '74120',
                         state: 'WA',
                         city: 'Lake Dallas',
                         street_address: '2215 Merrill Wells' } }
    end

    context 'with feature flag on' do
      it 'is successful and has a response' do
        action
        expect(response).to be_ok
      end
    end

    context 'with feature flag off' do
      it 'is a 400' do
        action
        expect(response).to be_bad_request
      end
    end
  end
end

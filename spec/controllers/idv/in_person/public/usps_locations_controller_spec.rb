require 'rails_helper'

RSpec.describe Idv::InPerson::Public::UspsLocationsController do
  include Rails.application.routes.url_helpers

  describe '#index' do
    subject(:action) do
      post :index,
           params: {
             address: {
               address: '87060 Colby Radial, Stephenmouth, OK 73339-7909',
               zip_code: '73339',
               state: 'OK',
               city: 'Stephenmouth',
               street_address: '87060 Colby Radial',
             },
           }
    end

    it 'is successful and has a response' do
      action
      expect(response).to be_ok
    end
  end
end

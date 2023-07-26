require 'rails_helper'

RSpec.describe Idv::InPerson::Public::AddressSearchController do
  include Rails.application.routes.url_helpers

  describe '#index' do
    subject(:action) do
      post :index,
           params:
            { address: '100 main' }
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

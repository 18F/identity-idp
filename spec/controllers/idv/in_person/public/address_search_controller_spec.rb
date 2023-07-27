require 'rails_helper'

RSpec.describe Idv::InPerson::Public::AddressSearchController do
  include Rails.application.routes.url_helpers

  describe '#index' do
    subject(:action) do
      post :index, params: { address: '100 main' }
    end

    context 'with feature flag off' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_public_address_search_enabled).
          and_return(false)
      end

      it 'is a 400' do
        action

        expect(response).to be_not_found
      end
    end

    context 'with feature flag on' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_public_address_search_enabled).
          and_return(true)
      end

      it 'is successful and has a response' do
        action
        expect(response).to be_ok
      end
    end
  end
end

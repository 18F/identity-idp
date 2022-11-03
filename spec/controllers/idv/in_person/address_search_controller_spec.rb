require 'rails_helper'

describe Idv::InPerson::AddressSearchController do
  include IdvHelper

  let(:user) { create(:user) }
  let(:sp) { nil }
  let(:in_person_proofing_enabled) { true }

  before do
    stub_analytics
    stub_sign_in(user) if user
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(controller).to receive(:current_sp).and_return(sp)
  end

  describe '#index' do
    let(:geocoder) { double('Geocoder') }
    let(:suggestions) do
      [
        OpenStruct.new({ magic_key: 'a' }),
      ]
    end

    let(:addresses) do
      [
        { name: 'Address 1' },
        { name: 'Address 2' },
        { name: 'Address 3' },
        { name: 'Address 4' },
      ]
    end
    subject(:response) { get :index }

    before do
      allow(controller).to receive(:geocoder).and_return(geocoder)
      allow(geocoder).to receive(:find_address_candidates).and_return(addresses)
      allow(geocoder).to receive(:suggest).and_return(suggestions)
    end

    context 'with successful fetch' do
      it 'gets successful response' do
        response = get :index
        json = response.body
        addresses = JSON.parse(json)
        expect(addresses.length).to eq 1
      end
    end

    context 'with unsuccessful fetch' do
      before do
        exception = Faraday::ConnectionFailed.new('error')
        allow(geocoder).to receive(:suggest).and_raise(exception)
      end

      it 'gets an empty pilot response' do
        response = get :index
        json = response.body
        addresses = JSON.parse(json)
        expect(addresses.length).to eq 0
      end
    end

    context 'with feature disabled' do
      let(:in_person_proofing_enabled) { false }

      it 'renders 404' do
        expect(response.status).to eq(404)
      end
    end
  end
end

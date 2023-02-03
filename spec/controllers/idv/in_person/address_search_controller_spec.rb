require 'rails_helper'

describe Idv::InPerson::AddressSearchController do
  include IdvHelper

  let(:user) { create(:user) }
  let(:sp) { nil }
  let(:arcgis_search_enabled) { true }

  before do
    stub_analytics
    stub_sign_in(user) if user
    allow(IdentityConfig.store).to receive(:arcgis_search_enabled).
      and_return(arcgis_search_enabled)
    allow(controller).to receive(:current_sp).and_return(sp)
  end

  describe '#index' do
    let(:geocoder) { double('Geocoder') }

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
    end

    context 'with successful fetch' do
      it 'gets successful response' do
        response = get :index
        expect(response.status).to eq(200)
        addresses = JSON.parse(response.body)
        expect(addresses.length).to eq 1
      end

      context 'with no address candidates' do
        let(:addresses) do
          []
        end

        it 'returns empty array' do
          response = get :index
          expect(response.status).to eq(200)
          addresses = JSON.parse(response.body)
          expect(addresses.length).to eq 0
          expect(@analytics).to have_logged_event(
            'IdV: in person proofing location search submitted',
            success: false,
            errors: 'No address candidates found by arcgis',
            result_total: nil,
            exception_class: nil,
            exception_message: nil,
            reason: nil,
            response_status_code: nil,
          )
        end
      end
    end

    context 'with unsuccessful fetch' do
      before do
        exception = Faraday::ConnectionFailed.new('error')
        allow(geocoder).to receive(:find_address_candidates).and_raise(exception)
      end

      it 'gets an empty pilot response' do
        response = get :index
        expect(response.status).to eq(422)
        addresses = JSON.parse(response.body)
        expect(addresses.length).to eq 0
      end
    end

    context 'with a timeout error' do
      before do
        exception = Faraday::TimeoutError.new
        allow(geocoder).to receive(:find_address_candidates).and_raise(exception)
      end

      it 'returns an error code' do
        response = get :index
        expect(response.status).to eq(422)
        addresses = JSON.parse(response.body)
        expect(addresses.length).to eq 0
      end
    end

    context 'with feature disabled' do
      let(:arcgis_search_enabled) { false }

      it 'renders 404' do
        expect(response.status).to eq(404)
      end
    end
  end
end

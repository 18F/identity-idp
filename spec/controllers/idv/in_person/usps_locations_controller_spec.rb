require 'rails_helper'

describe Idv::InPerson::UspsLocationsController do
  include IdvHelper

  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }
  let(:selected_location) do
    {
      usps_location: {
        formatted_city_state_zip: 'BALTIMORE, MD, 21233-9715',
        name: 'BALTIMORE',
        phone: '410-555-1212',
        saturday_hours: '8:30 AM - 5:00 PM',
        street_address: '123 Fake St.',
        sunday_hours: 'Closed',
        weekday_hours: '8:30 AM - 7:00 PM',
      },
    }
  end

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
  end

  describe '#index' do
    let(:proofer) { double('Proofer') }
    let(:locations) {
      [
        { name: 'Location 1' },
        { name: 'Location 2' },
        { name: 'Location 3' },
        { name: 'Location 4' },
      ]
    }
    subject(:response) { get :index }

    before do
      allow(UspsInPersonProofing::Proofer).to receive(:new).and_return(proofer)
    end

    context 'with successful fetch' do
      before do
        allow(proofer).to receive(:request_pilot_facilities).and_return(locations)
      end

      it 'gets successful pilot response' do
        response = get :index
        json = response.body
        facilities = JSON.parse(json)
        expect(facilities.length).to eq 4
      end
    end

    context 'with unsuccessful fetch' do
      before do
        exception = Faraday::ConnectionFailed.new('error')
        allow(proofer).to receive(:request_pilot_facilities).and_raise(exception)
      end

      it 'gets an empty pilot response' do
        response = get :index
        json = response.body
        facilities = JSON.parse(json)
        expect(facilities.length).to eq 0
      end
    end
  end

  describe '#update' do
    it 'writes the passed location to in-person enrollment' do
      put :update, params: selected_location

      expect(user.reload.establishing_in_person_enrollment.selected_location_details).to eq(
        selected_location[:usps_location].as_json,
      )
    end

    context 'with hybrid user' do
      let(:user) { nil }
      let(:effective_user) { create(:user) }

      before do
        session[:doc_capture_user_id] = effective_user.id
      end

      it 'writes the passed location to in-person enrollment associated with effective user' do
        put :update, params: selected_location

        expect(
          effective_user.reload.establishing_in_person_enrollment.selected_location_details,
        ).to eq(selected_location[:usps_location].as_json)
      end
    end
  end
end

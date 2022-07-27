require 'rails_helper'

describe Idv::InPerson::UspsLocationsController do
  include IdvHelper

  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }

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

  context 'with a session' do
    let(:idv_session) do
      Idv::Session.new(
        user_session: {},
        current_user: user,
        service_provider: nil,
      )
    end
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
      allow(subject).to receive(:idv_session).and_return(idv_session)
    end

    describe '#update' do
      it 'writes the passed location to session' do
        put :update, params: selected_location

        selected_location[:usps_location].keys.each do |key|
          expect(idv_session.applicant[:selected_location_details][key.to_s]).
            to eq(selected_location[:usps_location][key])
        end
      end
    end

    describe '#show' do
      it 'loads the saved location from session' do
        put :update, params: selected_location

        response = get :show
        body = JSON.parse(response.body)
        selected_location[:usps_location].keys.each do |key|
          expect(body[key.to_s.camelize(:lower)]).
            to eq(selected_location[:usps_location][key])
        end
      end
    end
  end
end

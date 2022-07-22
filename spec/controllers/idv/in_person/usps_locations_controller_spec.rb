require 'rails_helper'

describe Idv::InPerson::UspsLocationsController do

    describe "#index" do
        subject(:response) { get :index }
        
        it 'gets successful pilot response' do
            response = get :index
            json = response.body
            facilities = JSON.parse(json)
            expect(facilities.length).to eq 10
            expect(facilities).to eq (Idp::Constants::MOCK_IDV_PILOT_LOCATIONS)
        end
    end
end
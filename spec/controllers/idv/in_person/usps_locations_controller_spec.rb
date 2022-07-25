require 'rails_helper'

describe Idv::InPerson::UspsLocationsController do
  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
  end

  describe '#index' do
    subject(:response) { get :index }

    it 'gets successful pilot response' do
      response = get :index
      json = response.body
      facilities = JSON.parse(json)
      expect(facilities.length).to eq 7
    end
  end

  describe '#update' do
  end

  describe '#show' do
  end
end

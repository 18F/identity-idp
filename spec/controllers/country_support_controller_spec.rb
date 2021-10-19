require 'rails_helper'

RSpec.describe CountrySupportController do
  describe '#index' do
    it 'renders country support as JSON' do
      get :index

      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:countries][:US][:supports_sms]).to eq(true)
    end
  end
end

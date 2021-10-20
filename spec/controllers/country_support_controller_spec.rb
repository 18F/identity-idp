require 'rails_helper'

RSpec.describe CountrySupportController do
  describe '#index' do
    it 'renders country support as JSON' do
      get :index

      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:countries][:US]).to eq(
        name: 'United States',
        country_code: '1',
        supports_sms: true,
        supports_voice: true,
      )
    end
  end
end

require 'rails_helper'

RSpec.describe Risc::ConfigurationController do
  describe '#index' do
    let(:json_response) { JSON.parse(response.body).with_indifferent_access }

    it 'renders information about the RISC profile' do
      get :index

      expect(json_response).to eq(RiscConfigurationPresenter.new.configuration.as_json)
    end
  end
end

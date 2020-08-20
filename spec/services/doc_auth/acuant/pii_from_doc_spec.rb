require 'rails_helper'

describe DocAuth::Acuant::PiiFromDoc do
  include DocAuthHelper

  let(:response_body) { JSON.parse(AcuantFixtures.get_results_response_success) }

  describe '#call' do
    it 'correctly parses the pii data from acuant and returns a hash' do
      results = described_class.new(response_body).call
      expect(results).to eq(
        first_name: 'JANE',
        middle_name: nil,
        last_name: 'DOE',
        address1: '1000 E AVENUE E',
        city: 'BISMARCK',
        state: 'ND',
        zipcode: '58501',
        dob: '04/01/1984',
        state_id_number: 'DOE-84-1165',
        state_id_jurisdiction: 'ND',
        state_id_type: 'drivers_license',
      )
    end
  end
end

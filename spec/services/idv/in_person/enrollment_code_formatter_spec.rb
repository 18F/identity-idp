require 'rails_helper'

describe Idv::InPerson::EnrollmentCodeFormatter do
  describe '.format' do
    it 'returns a formatted code' do
      result = described_class.format('2048702198804358')

      expect(result).to eq '2048-7021-9880-4358'
    end
  end
end

require 'rails_helper'

RSpec.describe Phonelib do
  describe '.default_country + #e164' do
    it 'is set to US so that 10 digit phone numbers get the +1 in e164' do
      expect(Phonelib.parse('888 867 5309').e164).to eq('+18888675309')
    end
  end
end

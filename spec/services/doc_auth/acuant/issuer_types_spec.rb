require 'rails_helper'

RSpec.describe DocAuth::Acuant::IssuerTypes do
  describe '.from_int' do
    it 'is a result code for the int' do
      issuer_type = DocAuth::Acuant::IssuerTypes.from_int(1)
      expect(issuer_type).to be_a(DocAuth::Acuant::IssuerTypes::IssuerType)
    end

    it 'is nil when there is no matching code' do
      issuer_type = DocAuth::Acuant::IssuerTypes.from_int(999)
      expect(issuer_type).to be_nil
    end
  end
end

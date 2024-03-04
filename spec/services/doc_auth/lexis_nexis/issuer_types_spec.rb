require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::IssuerTypes do
  describe '.from_int' do
    it 'is a result code for the int' do
      issuer_type = DocAuth::LexisNexis::IssuerTypes.from_int(1)
      expect(issuer_type).to be_a(DocAuth::LexisNexis::IssuerTypes::IssuerType)
    end

    it 'is nil when there is no matching code' do
      issuer_type = DocAuth::LexisNexis::IssuerTypes.from_int(999)
      expect(issuer_type).to be_nil
    end
  end
end

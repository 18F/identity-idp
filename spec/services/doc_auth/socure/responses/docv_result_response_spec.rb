require 'rails_helper'

RSpec.describe DocAuth::Socure::Responses::DocvResultResponse do
  subject(:docv_response) do
    http_response = Struct.new(:body).new(SocureDocvFixtures.pass_json)
    described_class.new(http_response:)
  end

  context 'Socure says OK and the PII is valid' do
    it 'succeeds' do
      expect(docv_response.success?).to be(true)
    end
  end

  context 'Socure says OK but the PII is invalid' do
    before do
      allow_any_instance_of(Idv::DocPiiForm).to receive(:zipcode).and_return(:invalid_junk)
    end

    it 'fails' do
      expect(docv_response.success?).to be(false)
    end

    it 'with a pii failure error' do
      expect(docv_response.errors).to eq({ pii_validation: 'failed' })
    end
  end
end

require 'rails_helper'
require 'faraday'

describe DocAuth::LexisNexis::Responses::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.true_id_response_success }
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  let(:failure_response_body) { LexisNexisFixtures.true_id_response_failure }
  let(:failure_response) do
    instance_double(Faraday::Response, status: 200, body: failure_response_body)
  end

  context 'when the response is a success' do
    it 'is a successful result' do
      expect(described_class.new(success_response).successful_result?).to eq(true)
    end
    it 'has no error messages' do
      expect(described_class.new(success_response).error_messages).to be_empty
    end
    it 'has extra attributes' do
      extra_attributes = described_class.new(success_response).extra_attributes
      expect(extra_attributes).not_to be_empty
    end
    it 'has PII data' do
      pii_from_doc = described_class.new(success_response).pii_from_doc
      expect(pii_from_doc).not_to be_empty
    end
  end
end

require 'rails_helper'
require 'faraday'

describe DocAuth::LexisNexis::Responses::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.true_id_response_success_2 }
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  let(:failure_response_body) { LexisNexisFixtures.true_id_response_failure }
  let(:failure_response) do
    instance_double(Faraday::Response, status: 200, body: failure_response_body)
  end

  context 'when the response is a success' do
    it 'is a successful result' do
      expect(described_class.new(success_response, false).successful_result?).to eq(true)
    end
    it 'has no error messages' do
      expect(described_class.new(success_response, false).error_messages).to be_empty
    end
    it 'has extra attributes' do
      extra_attributes = described_class.new(success_response, false).extra_attributes
      expect(extra_attributes).not_to be_empty
    end
    it 'has PII data' do
      pii_from_doc = described_class.new(success_response, false).pii_from_doc
      expect(pii_from_doc).not_to be_empty
    end
  end

  context 'when response is not a success' do
    it 'it produces appropriate errors' do
      output = described_class.new(failure_response, false).to_h
      errors = output[:errors]

      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general)
      expect(errors[:general]).to contain_exactly(
        I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness'),
      )
    end
  end
end

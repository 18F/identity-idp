require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Requests::TrueIdRequest do
  let(:account_id) { 'test_account' }
  let(:workflow) { 'test_workflow' }
  let(:base_url) { 'https://lexis.nexis.example.com' }
  let(:path) { "/restws/identity/v3/accounts/#{account_id}/workflows/#{workflow}/conversations" }
  let(:full_url) { base_url + path }
  let(:config) do
    DocAuth::LexisNexis::Config.new(
      trueid_account_id: account_id,
      base_url: base_url,
      trueid_liveness_workflow: 'test_workflow',
      trueid_noliveness_workflow: 'test_workflow_noliveness',
    )
  end
  let(:subject) do
    described_class.new(
      config: config,
      front_image: DocAuthImageFixtures.document_front_image,
      back_image: DocAuthImageFixtures.document_back_image,
      selfie_image: DocAuthImageFixtures.selfie_image,
      liveness_checking_enabled: true,
    )
  end

  context 'with liveness checking enabled' do
    it 'uploads the image and returns a successful result' do
      request_stub = stub_request(:post, full_url).to_return(body: response_body, status: 201)

      response = subject.fetch

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(request_stub).to have_been_requested
    end
  end
end

def response_body
  {
    Status: {
      TransactionStatus: 'passed',
    },
    Products: [
      {
        ProductType: 'TrueID',
        ProductStatus: 'pass',
        ParameterDetails: [
          {
            Group: 'AUTHENTICATION_RESULT',
            Name: 'DocAuthResult',
            Values: [
              {
                Value: 'Passed',
              },
            ],
          },
        ],
      },
    ],
  }.to_json
end

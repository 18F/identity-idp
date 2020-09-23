require 'rails_helper'

describe DocAuth::LexisNexis::Requests::TrueIdRequest do
  let(:account_id) { 'test_account' }
  let(:workflow) { 'test_workflow' }
  let(:base_url) { Figaro.env.lexisnexis_base_url }
  let(:path) { "/restws/identity/v3/accounts/#{account_id}/workflows/#{workflow}/conversations" }
  let(:full_url) { base_url + path }
  let(:subject) do
    described_class.new(
      front_image: DocAuthImageFixtures.document_front_image,
      back_image: DocAuthImageFixtures.document_back_image,
      selfie_image: DocAuthImageFixtures.selfie_image,
      liveness_checking_enabled: true,
    )
  end

  before do
    allow(subject).to receive(:account_id).and_return(account_id)
    allow(subject).to receive(:workflow).and_return(workflow)
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

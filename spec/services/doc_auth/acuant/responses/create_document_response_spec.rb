require 'rails_helper'

describe DocAuth::Acuant::Responses::CreateDocumentResponse do
  it 'contains the instance_id from the response' do
    http_response = instance_double(
      Faraday::Response,
      body: AcuantFixtures.create_document_response,
    )

    response = described_class.new(http_response)

    expect(response.success?).to eq(true)
    expect(response.instance_id).to eq('this-is-a-test-instance-id') # Value from the fixture
    expect(response.errors).to eq({})
    expect(response.exception).to be_nil
  end
end

require 'rails_helper'

describe DocAuth::Acuant::Requests::GetResultsRequest do
  describe '#fetch' do
    let(:instance_id) { '123abc' }
    let(:url) do
      URI.join(Figaro.env.acuant_assure_id_url, "/AssureIDService/Document/#{instance_id}")
    end
    let(:response_body) { AcuantFixtures.get_results_response_success }

    it 'sends a request and return the response' do
      request_stub = stub_request(:get, url).to_return(body: response_body)

      response = described_class.new(instance_id: instance_id).fetch

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(response.pii_from_doc).to_not be_empty
      expect(request_stub).to have_been_requested
    end
  end
end

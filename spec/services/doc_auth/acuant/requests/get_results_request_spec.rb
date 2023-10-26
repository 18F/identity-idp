require 'rails_helper'

RSpec.describe DocAuth::Acuant::Requests::GetResultsRequest do
  describe '#fetch' do
    let(:instance_id) { '123abc' }
    let(:url) do
      URI.join(assure_id_url, "/AssureIDService/Document/#{instance_id}")
    end
    let(:response_body) { AcuantFixtures.get_results_response_success }

    let(:assure_id_url) { 'https://acuant.assureid.example.com' }
    let(:config) { DocAuth::Acuant::Config.new(assure_id_url: assure_id_url) }

    it 'sends a request and return the response' do
      request_stub = stub_request(:get, url).to_return(body: response_body)

      response = described_class.new(config: config, instance_id: instance_id).fetch

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(response.pii_from_doc).to_not be_empty
      expect(request_stub).to have_been_requested
    end

    it 'get general error for 4xx' do
      stub_request(:get, url).to_return(status: 440)
      response = described_class.new(config: config, instance_id: instance_id).fetch
      expect(response.errors).to include(:general, :front, :back)
      expect(response.network_error?).to eq(false)
    end

    it 'get network error for 500' do
      stub_request(:get, url).to_return(status: 500)
      response = described_class.new(config: config, instance_id: instance_id).fetch
      expect(response.errors).to have_key(:network)
      expect(response.network_error?).to eq(true)
    end
  end
end

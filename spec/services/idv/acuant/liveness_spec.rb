require 'rails_helper'

describe Idv::Acuant::Liveness do
  describe '#liveness' do
    let(:acuant_base_url) { 'https://example.com' }
    let(:path) { '/api/v1/liveness' }
    let(:body) { 'body' }

    it 'returns a good status' do
      stub_request(:post, acuant_base_url + path).
        with(headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }).
        to_return(status: 200, body: body)

      result = subject.liveness(body)

      expect(result).to eq([true, body])
    end
  end
end

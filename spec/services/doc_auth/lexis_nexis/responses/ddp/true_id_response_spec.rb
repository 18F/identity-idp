require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Responses::Ddp::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.ddp_true_id_response_success }
  let(:failure_response_body) { LexisNexisFixtures.ddp_true_id_response_fail }
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  let(:failure_response) do
    instance_double(Faraday::Response, status: 200, body: failure_response_body)
  end
  let(:config) do
    DocAuth::LexisNexis::Config.new
  end

  context 'when the response is a success' do
    let(:response) do
      described_class.new(
        http_response: success_response,
        config:,
      )
    end

    it 'is a successful result' do
      expect(response.successful_result?).to eq(true)
      expect(response.success?).to eq(true)
    end
  end

  context 'when the response is a failure' do
    let(:response) do
      described_class.new(
        http_response: failure_response,
        config: nil,
      )
    end

    it 'is not a successful result' do
      expect(response.successful_result?).to eq(false)
      expect(response.success?).to eq(false)
    end
  end
end

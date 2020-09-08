require 'rails_helper'
require 'faraday'

describe DocAuth::LexisNexis::Responses::TrueIdResponse do
  let(:failure_response_body) { LexisNexisFixtures.true_id_response_failure }
  let(:failure_response) { instance_double(Faraday::Response, status: 200, body: failure_response_body)}

  before do
    # Do nothing
  end

  after do
    # Do nothing
  end

  context 'when response is not a success' do
    it 'produces appropriate errors' do
      output = described_class.new(failure_response)
      puts output.inspect
    end
  end
end

require 'rails_helper'

describe Proofing::LexisNexis::PhoneFinder::Result do
  let(:response_body) { LexisNexisFixtures.instant_verify_success_response_json }
  let(:response_status) { 200 }
  let(:http_response) do
    Faraday::Response.new(response_body: response_body, status: response_status)
  end
  let(:verification_response) do
    Proofing::LexisNexis::Response.new(http_response)
  end

  subject { described_class.new(verification_response) }

  context 'successful response' do
    it 'returns a successful verified result' do
      expect(subject.success?).to eq(true)
    end
  end
end

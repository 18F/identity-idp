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

  it 'renders LexisNexis metadata' do
    # expected values originate in the fixture
    expect(subject.reference).to eq('Reference1')
    expect(subject.transaction_id).to eq('8624642277235233040')
  end

  context 'successful response' do
    it 'returns a successful verified result' do
      expect(subject.success?).to eq(true)
    end
  end

  context 'failed to match response' do
    let(:response_body) { LexisNexisFixtures.instant_verify_failure_response_json }

    it 'returns a failed to match verified result' do
      expect(subject.success?).to eq(false)
      expect(subject.verification_errors).to include(
        :base,
        :SomeOtherProduct,
        :InstantVerify,
      )
    end
  end
end

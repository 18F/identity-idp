require 'rails_helper'

RSpec.describe AccountCreation::DeviceProfile::VerificationRequest do
  let(:dob) { '1980-01-01' }
  let(:applicant) do
    {
      threatmetrix_session_id: 'UNIQUE_SESSION_ID',
      email: 'test@example.com',
      request_ip: '127.0.0.1',
    }
  end

  let(:response_body) { LexisNexisFixtures.ddp_success_response_json }
  subject do
    described_class.new(applicant: applicant, config: LexisNexisFixtures.example_ddp_config)
  end

  before do
    allow(IdentityConfig.store).to receive(:authentication_tmx_policy).
      and_return('authentication-test-policy')
  end

  describe '#body' do
    it 'returns a properly formed request body' do
      expect(subject.body).to eq(LexisNexisFixtures.ddp_account_creation_request_json)
    end
  end

  describe '#url' do
    it 'returns a url for the DDP session query endpoint' do
      expect(subject.url).to eq('https://example.com/api/session-query')
    end
  end

  describe '#build_request_headers' do
    before do
      allow(IdentityConfig.store).to receive(:lexisnexis_hmac_auth_enabled).and_return(true)
    end

    it 'does not include an Authorization header' do
      expect(subject.send(:build_request_headers)['Authorization']).to be_nil
    end
  end
end

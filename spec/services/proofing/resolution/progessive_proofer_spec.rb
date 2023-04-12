require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
  let(:should_proof_state_id) { true }
  let(:double_address_verification) { false }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:timer) { JobHelpers::Timer.new }
  let(:user) { create(:user, :signed_up) }

  let(:instance) { described_class.new }

  describe '#proof' do
    subject(:proof) do
      instance.proof(
        applicant_pii: applicant_pii,
        double_address_verification: double_address_verification,
        request_ip: request_ip,
        should_proof_state_id: should_proof_state_id,
        threatmetrix_session_id: threatmetrix_session_id,
        timer: timer,
        user_email: user.confirmed_email_addresses.first.email,
      )
    end

    it 'returns a ResultAdjudicator' do
      expect(proof).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
    end

    it 'makes a request to Instant Verify'

    context 'user is not in an AAMVA jurisdiction' do
      it 'does not make a request to AAMVA'
    end

    context 'Instant Verify passes' do
      context 'user is in an AAMVA jurisdiction' do
        it 'makes a request to AAMVA'
      end
    end
  end
end

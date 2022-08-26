require 'rails_helper'

RSpec.describe Proofing::Mock::ResolutionMockClient do
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(uuid: '1234-abcd') }
  subject(:instance) { described_class.new }

  expect_mock_proofer_matches_real_proofer(
    mock_proofer_class: Proofing::Mock::ResolutionMockClient,
    real_proofer_class: Proofing::LexisNexis::InstantVerify::Proofer,
  )

  describe '#proof' do
    subject(:result) { instance.proof(applicant) }

    context 'with simulated failed to contact by SSN' do
      let(:applicant) { super().merge(ssn: '000-00-0000') }

      it 'returns an unsuccessful result with exception' do
        expect(result.success?).to eq(false)
        expect(result.errors).to be_blank
        expect(result.exception).to be_present
        expect(result.exception.message).to eq('Failed to contact proofing vendor')
      end

      context 'with dashes omitted from SSN' do
        let(:applicant) { super().merge(ssn: '000000000') }

        it 'returns an unsuccessful result with exception' do
          expect(result.success?).to eq(false)
          expect(result.errors).to be_blank
          expect(result.exception).to be_present
          expect(result.exception.message).to eq('Failed to contact proofing vendor')
        end
      end
    end
  end
end

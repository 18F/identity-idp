require 'rails_helper'

RSpec.describe AccountCreation::DeviceProfile::Proofer do
  let(:applicant) do
    {
      threatmetrix_session_id: 'UNIQUE_SESSION_ID',
      email: 'test@example.com',
      request_ip: '127.0.0.1',
    }
  end

  let(:verification_request) do
    AccountCreation::DeviceProfile::VerificationRequest.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_config,
    )
  end

  subject do
    described_class.new(LexisNexisFixtures.example_config.to_h)
  end

  describe '#proof' do
    before do
      stub_request(
        :post,
        verification_request.url,
      ).to_return(
        body: response_body,
        status: 200,
      )
    end
    context 'when the response passes threatmetrix' do
      let(:response_body) { LexisNexisFixtures.ddp_success_response_json }

      it 'is a successful result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.review_status).to eq('pass')
        expect(result.session_id).to eq('super-cool-test-session-id')
        expect(result.account_lex_id).to eq('super-cool-test-lex-id')
      end
    end

    context 'when the response raises an exception' do
      let(:response_body) { '' }

      it 'returns an exception result' do
        error = RuntimeError.new('hi')

        expect(NewRelic::Agent).to receive(:notice_error).with(error)

        stub_request(
          :post,
          verification_request.url,
        ).to_raise(error)

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to be_empty
        expect(result.exception).to eq(error)
      end
    end

    context 'when the review status has an unexpected value' do
      let(:response_body) { LexisNexisFixtures.ddp_unexpected_review_status_response_json }

      it 'returns an exception result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.exception.inspect).to include(LexisNexisFixtures.ddp_unexpected_review_status)
      end
    end
  end
end

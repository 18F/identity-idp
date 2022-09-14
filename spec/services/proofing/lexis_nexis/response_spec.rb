require 'rails_helper'

describe Proofing::LexisNexis::Response do
  let(:response_status_code) { 200 }
  let(:response_body) { LexisNexisFixtures.instant_verify_success_response_json }
  let(:response) do
    Faraday::Response.new(
      status: response_status_code,
      body: response_body,
    )
  end

  subject { Proofing::LexisNexis::Response.new(response) }

  describe '.new' do
    context 'with an HTTP status error code' do
      let(:response_status_code) { 500 }
      let(:response_body) { 'something went horribly wrong' }

      it 'raises an error that includes the status code and the body' do
        expect { subject }.to raise_error(
          Proofing::LexisNexis::Response::UnexpectedHTTPStatusCodeError,
          "Unexpected status code '500': something went horribly wrong",
        )
      end
    end
  end

  describe '#verification_errors' do
    context 'with a failed verification' do
      let(:response_body) { LexisNexisFixtures.instant_verify_identity_not_found_response_json }
      it 'returns a hash of errors' do
        errors = subject.verification_errors

        expect(errors).to be_a(Hash)
        expect(errors).to include(:base, :'Execute Instant Verify')
      end
    end

    context 'with a passed verification' do
      it { expect(subject.verification_errors).to eq({}) }
    end
  end

  describe '#verification_status' do
    context 'passed' do
      it { expect(subject.verification_status).to eq('passed') }
    end

    context 'failed' do
      let(:response_body) { LexisNexisFixtures.instant_verify_identity_not_found_response_json }
      it { expect(subject.verification_status).to eq('failed') }

      context 'with a transaction error' do
        let(:response_body) { LexisNexisFixtures.instant_verify_error_response_json }

        it 'returns a hash of errors' do
          errors = subject.verification_errors

          expect(errors).to match(base: a_string_starting_with('Response error with code'))
        end
      end

      context 'with an invalid transaction status' do
        let(:response_body) do
          parsed_body = JSON.parse(super())
          parsed_body['Status']['TransactionStatus'] = 'fake_status'
          parsed_body.to_json
        end

        it 'returns a hash of errors' do
          errors = subject.verification_errors

          expect(errors).to be_a(Hash)
          expect(errors).to include(:base, :'Execute Instant Verify')
          expect(errors[:base]).to eq("Invalid status in response body: 'fake_status'")
        end
      end
    end
  end
end

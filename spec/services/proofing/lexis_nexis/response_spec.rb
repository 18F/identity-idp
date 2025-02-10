require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Response do
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
      it 'returns a hash of error' do
        errors = subject.verification_errors

        expect(errors).to have_key(:'Execute Instant Verify')
      end
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

  describe '#product_list' do
    context 'for a response with a product list' do
      it 'returns the product list' do
        product_list = subject.product_list

        expect(product_list.length).to eq(1)
        expect(product_list.first['ProductType']).to eq('InstantVerify')
      end
    end

    context 'for a response without a product list' do
      let(:response_body) { LexisNexisFixtures.instant_verify_error_response_json }

      it 'returns an empty array' do
        product_list = subject.product_list

        expect(product_list).to eq([])
      end
    end
  end

  describe '#transaction_reason_code' do
    context 'for a response with a transaction reason code' do
      let(:response_body) { LexisNexisFixtures.instant_verify_identity_not_found_response_json }

      it 'returns the reason code' do
        expect(subject.transaction_reason_code).to eq('total.scoring.model.verification.fail')
      end
    end

    context 'for a response without a transaciton reason code' do
      it 'returns nil' do
        expect(subject.transaction_reason_code).to eq(nil)
      end
    end
  end

  describe '#response_body' do
    context 'the result includes invalid JSON' do
      let(:response_body) { '$":^&' }

      it 'raises a JSON parse error with a generic error message' do
        expect { subject.response_body }.to raise_error(
          JSON::ParserError,
          'An error occured parsing the response body JSON, status=200 content_type=',
        )
      end
    end
  end
end

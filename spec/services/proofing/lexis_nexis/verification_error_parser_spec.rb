require 'rails_helper'

RSpec.describe Proofing::LexisNexis::VerificationErrorParser do
  let(:response_body) do
    JSON.parse(LexisNexisFixtures.instant_verify_identity_not_found_response_json)
  end
  subject(:error_parser) { described_class.new(response_body) }

  describe '#parsed_errors' do
    subject(:errors) { error_parser.parsed_errors }

    it 'should return an array of errors from the response' do
      expect(errors[:base]).to start_with('Verification failed with code:')
      expect(errors[:'Execute Instant Verify']).to eq(response_body['Products'].first)
    end

    it 'should not log a passing response containing no important information' do
      response_body['Products'].first['ExecutedStepName'] = 'Executed Fake Product'
      response_body['Products'].first['ProductType'] = 'Fake Product'
      response_body['Products'].first['ProductStatus'] = 'pass'
      response_body['Products'].first['Items'].map { |i| i.delete('ItemReason') }

      expect(errors[:'Executed Fake Product']).to eq(nil)
    end

    it 'should log any Instant Verify response, including a pass' do
      response_body['Products'].first['ProductStatus'] = 'pass'
      response_body['Products'].first['Items'].map { |i| i.delete('ItemReason') }

      expect(errors[:'Execute Instant Verify']).to be_a Hash
    end

    it 'should log any response with an ItemReason, including a pass' do
      response_body['Products'].first['ExecutedStepName'] = 'Executed Fake Product'
      response_body['Products'].first['ProductType'] = 'Fake Product'
      response_body['Products'].first['ProductStatus'] = 'pass'

      expect(errors[:'Executed Fake Product']).to be_a Hash
    end
  end

  describe 'PhoneFinder detail logging' do
    subject(:errors) do
      described_class.new(response_body, review_status:).parsed_errors
    end

    let(:review_status) { nil }
    let(:transaction_status) { 'passed' }
    let(:checks_status) { 'pass' }
    let(:response_body) do
      {
        'Status' => { 'TransactionStatus' => transaction_status },
        'Products' => [
          {
            'ExecutedStepName' => 'PhoneFinder',
            'ProductType' => 'PhoneFinder',
            'ProductStatus' => 'pass',
            'ParameterDetails' => [{ 'Name' => 'Phone', 'Value' => '5551234567' }],
            'Items' => [{ 'ItemName' => 'VOIPPhone', 'ItemStatus' => 'pass' }],
          },
          {
            'ExecutedStepName' => 'PhoneFinder Checks',
            'ProductType' => 'PhoneFinder_Decision',
            'ProductStatus' => checks_status,
          },
        ],
      }
    end

    shared_examples 'logs the PhoneFinder detail with Items but no PII' do
      it 'logs the PhoneFinder detail product with its Items and strips ParameterDetails' do
        expect(errors[:PhoneFinder]['Items']).to be_present
        expect(errors[:PhoneFinder]).not_to have_key('ParameterDetails')
      end
    end

    context 'when the raw PhoneFinder Checks decision fails' do
      let(:transaction_status) { 'failed' }
      let(:checks_status) { 'fail' }

      it_behaves_like 'logs the PhoneFinder detail with Items but no PII'
    end

    context 'when the raw response passes but the DDP review_status does not' do
      %w[review reject].each do |status|
        context "with review_status '#{status}'" do
          let(:review_status) { status }

          it_behaves_like 'logs the PhoneFinder detail with Items but no PII'
        end
      end
    end

    context 'when both the raw response and review_status pass' do
      let(:review_status) { 'pass' }

      it 'does not log the clean passing PhoneFinder detail product' do
        expect(errors[:PhoneFinder]).to be_nil
      end
    end
  end
end

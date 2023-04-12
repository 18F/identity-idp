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
end

require 'rails_helper'

RSpec.describe ProofingAgent::InstantVerify::BypassErrorCodeChecker do
  let(:bypass_codes) { ['dob', 'ssn'] }
  let(:product_type) { 'InstantVerify' }
  let(:items) do
    [
      { 'ItemName' => 'Addr1Zip_StateMatch', 'ItemStatus' => 'pass' },
      { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' },
      { 'ItemName' => 'SsnFullNameMatch', 'ItemStatus' => 'fail' },
    ]
  end
  let(:errors) do
    {
      base: "Verification failed with code: 'priority.error'",
      InstantVerify: {
        'ProductType' => product_type,
        'ProductStatus' => 'fail',
        'Items' => items,
      },
    }
  end

  subject(:checker) { described_class.new(errors:) }

  describe '#call' do
    before do
      allow(IdentityConfig.store)
        .to receive(:ssa_instant_verify_bypass_error_codes)
        .and_return(bypass_codes)
    end

    context 'when the correct bypass codes are presented' do
      it 'returns true' do
        expect(checker.call).to eq(true)
      end
    end

    context 'when only a subset of the bypass codes failed' do
      let(:items) do
        [{ 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' }]
      end

      it 'returns true' do
        expect(checker.call).to eq(true)
      end
    end

    context 'when multiple checks map to the same bypass code' do
      let(:items) do
        [
          { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' },
          { 'ItemName' => 'DOBYearVerified', 'ItemStatus' => 'fail' },
        ]
      end

      it 'returns true' do
        expect(checker.call).to eq(true)
      end
    end

    context 'when the user has extra failed attributes that are not bypass codes' do
      let(:items) do
        super() + [{ 'ItemName' => 'IdentityOccupancyVerified', 'ItemStatus' => 'fail' }]
      end

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when an unknown check fails' do
      let(:items) do
        [
          { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' },
          { 'ItemName' => 'MadeUpCheckThatDoesNotExist', 'ItemStatus' => 'fail' },
        ]
      end

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when the bypass codes are empty' do
      let(:bypass_codes) { [] }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when all of the checks pass' do
      let(:items) do
        [{ 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'pass' }]
      end

      it 'returns false because there is nothing to bypass' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when the product has no items' do
      let(:items) { [] }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    %w[InstantVerify Verification Verify].each do |type|
      context "when the product type is #{type}" do
        let(:product_type) { type }

        it 'returns true' do
          expect(checker.call).to eq(true)
        end
      end
    end

    context 'when the product type is not an instant verify product type' do
      let(:product_type) { 'PhoneFinder' }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when the errors use string keys' do
      let(:errors) { super().deep_stringify_keys }

      it 'returns true' do
        expect(checker.call).to eq(true)
      end
    end

    context 'when failures are spread across multiple products' do
      let(:errors) do
        {
          InstantVerify: {
            'ProductType' => 'InstantVerify',
            'Items' => [{ 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' }],
          },
          Verify: {
            'ProductType' => 'Verify',
            'Items' => [{ 'ItemName' => 'SsnFullNameMatch', 'ItemStatus' => 'fail' }],
          },
        }
      end

      it 'returns true when all failures are bypass codes' do
        expect(checker.call).to eq(true)
      end

      context 'and one product fails on a non-bypass attribute' do
        let(:bypass_codes) { ['dob'] }

        it 'returns false' do
          expect(checker.call).to eq(false)
        end
      end
    end

    context 'when errors is nil' do
      let(:errors) { nil }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when errors is empty' do
      let(:errors) { {} }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when errors does not respond to to_h' do
      let(:errors) { Object.new }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end
  end
end

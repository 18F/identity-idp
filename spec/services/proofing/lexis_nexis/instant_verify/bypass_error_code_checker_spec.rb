require 'rails_helper'

RSpec.describe Proofing::LexisNexis::InstantVerify::BypassErrorCodeChecker do
  let(:bypass_codes) do
    {
      'SsnFullNameMatch' => %w[
        ssn_fullname_not_match_fail
        identity_not_found_fail
        ssn_not_supplied_fail
        name_not_input_fail
      ],
      'SsnDeathMatchVerification' => %w[ssn_not_supplied_fail],
    }
  end
  let(:product_type) { 'InstantVerify' }
  let(:items) do
    [
      { 'ItemName' => 'Addr1Zip_StateMatch', 'ItemStatus' => 'pass' },
      failed_item('SsnFullNameMatch', 'ssn_fullname_not_match_fail'),
      failed_item('SsnDeathMatchVerification', 'ssn_not_supplied_fail'),
    ]
  end
  let(:errors) do
    {
      base: ["Verification failed with code: 'priority.error'"],
      InstantVerify: {
        'ProductType' => product_type,
        'ProductStatus' => 'fail',
        'Items' => items,
      },
    }
  end

  subject(:checker) { described_class.new(errors:, bypass_error_codes: bypass_codes) }

  def failed_item(name, code)
    {
      'ItemName' => name,
      'ItemReason' => { 'Code' => code },
      'ItemStatus' => 'fail',
    }
  end

  describe '#call' do
    context 'when every failed item is an allowed check and code pair' do
      it 'returns true' do
        expect(checker.call).to eq(true)
      end
    end

    context 'when only a subset of the bypass rules failed' do
      let(:items) { [failed_item('SsnFullNameMatch', 'identity_not_found_fail')] }

      it 'returns true' do
        expect(checker.call).to eq(true)
      end
    end

    context 'when the same code is allowed under more than one check' do
      %w[SsnFullNameMatch SsnDeathMatchVerification].each do |check_name|
        context "for #{check_name}" do
          let(:items) { [failed_item(check_name, 'ssn_not_supplied_fail')] }

          it 'returns true' do
            expect(checker.call).to eq(true)
          end
        end
      end
    end

    context 'when the check fails with a code that is not allowed for it' do
      let(:items) { [failed_item('SSNExists', 'ssn_not_verified_fail')] }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when an allowed code fails under a check it is not allowed for' do
      let(:items) { [failed_item('SSNExists', 'ssn_not_supplied_fail')] }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when a code is allowed for a different check than the one that failed' do
      let(:items) { [failed_item('SsnDeathMatchVerification', 'ssn_fullname_not_match_fail')] }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when an allowed failure is mixed with a disallowed failure' do
      let(:items) do
        super() + [failed_item('SSNExists', 'ssn_not_verified_fail')]
      end

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when a failed item has no ItemReason' do
      let(:items) { [{ 'ItemName' => 'SsnFullNameMatch', 'ItemStatus' => 'fail' }] }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when a failed item has an ItemReason that is not a hash' do
      let(:items) do
        [
          {
            'ItemName' => 'SsnFullNameMatch',
            'ItemReason' => 'ssn_not_supplied_fail',
            'ItemStatus' => 'fail',
          },
        ]
      end

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when a failed item has a blank code' do
      let(:items) { [failed_item('SsnFullNameMatch', '')] }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when an unknown check fails' do
      let(:items) do
        [
          failed_item('SsnFullNameMatch', 'ssn_fullname_not_match_fail'),
          failed_item('MadeUpCheckThatDoesNotExist', 'ssn_fullname_not_match_fail'),
        ]
      end

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when an item has a status other than pass' do
      let(:items) do
        [{
          'ItemName' => 'SSNExists',
          'ItemReason' => { 'Code' => 'ssn_not_verified_fail' },
          'ItemStatus' => 'review',
        }]
      end

      it 'treats it as a failure and returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when a passing item carries an allowed or disallowed code' do
      let(:items) do
        [
          failed_item('SsnFullNameMatch', 'ssn_fullname_not_match_fail'),
          {
            'ItemName' => 'SSNExists',
            'ItemReason' => { 'Code' => 'ssn_not_verified_fail' },
            'ItemStatus' => 'pass',
          },
        ]
      end

      it 'ignores the passing item' do
        expect(checker.call).to eq(true)
      end
    end

    context 'when the bypass codes are empty' do
      let(:bypass_codes) { {} }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when the bypass codes use symbol keys and symbol codes' do
      let(:bypass_codes) do
        { SsnFullNameMatch: [:ssn_fullname_not_match_fail, :ssn_not_supplied_fail] }
      end
      let(:items) { [failed_item('SsnFullNameMatch', 'ssn_fullname_not_match_fail')] }

      it 'normalizes them and returns true' do
        expect(checker.call).to eq(true)
      end

      it 'exposes the normalized bypass codes' do
        expect(checker.bypass_error_codes).to eq(
          'SsnFullNameMatch' => ['ssn_fullname_not_match_fail', 'ssn_not_supplied_fail'],
        )
      end
    end

    context 'when a check is configured with a single code instead of an array' do
      let(:bypass_codes) { { 'SsnFullNameMatch' => 'ssn_fullname_not_match_fail' } }
      let(:items) { [failed_item('SsnFullNameMatch', 'ssn_fullname_not_match_fail')] }

      it 'returns true' do
        expect(checker.call).to eq(true)
      end
    end

    [['dob', 'ssn'], nil, 'ssn_fullname_not_match_fail'].each do |invalid_codes|
      context "when the bypass codes are #{invalid_codes.inspect}" do
        let(:bypass_codes) { invalid_codes }

        it 'returns false' do
          expect(checker.call).to eq(false)
        end

        it 'exposes empty bypass codes' do
          expect(checker.bypass_error_codes).to eq({})
        end
      end
    end

    context 'when a check is configured with no codes' do
      let(:bypass_codes) { { 'SsnFullNameMatch' => [] } }

      it 'returns false' do
        expect(checker.call).to eq(false)
      end
    end

    context 'when all of the checks pass' do
      let(:items) do
        [{ 'ItemName' => 'SsnFullNameMatch', 'ItemStatus' => 'pass' }]
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
            'Items' => [failed_item('SsnFullNameMatch', 'ssn_fullname_not_match_fail')],
          },
          Verify: {
            'ProductType' => 'Verify',
            'Items' => [failed_item('SsnDeathMatchVerification', 'ssn_not_supplied_fail')],
          },
        }
      end

      it 'returns true when all failures are allowed' do
        expect(checker.call).to eq(true)
      end

      context 'and one product fails on a disallowed pair' do
        let(:bypass_codes) { { 'SsnFullNameMatch' => ['ssn_fullname_not_match_fail'] } }

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

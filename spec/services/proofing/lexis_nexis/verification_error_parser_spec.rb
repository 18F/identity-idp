require 'rails_helper'

RSpec.describe Proofing::LexisNexis::VerificationErrorParser do
  let(:response_body) { JSON.parse(LexisNexisFixtures.instant_verify_failure_response_json) }
  subject(:error_parser) { described_class.new(response_body) }

  describe '#initialize' do
    let(:response_body) do
      JSON.parse(LexisNexisFixtures.instant_verify_year_of_birth_fail_response_json)
    end

    it 'logs a message formatted as JSON' do
      expect(Rails.logger).to receive(:info) do |arg|
        expect(JSON.parse(arg, symbolize_names: true)).to eq(
          name: 'lexisnexis_partial_dob',
          original_passed: false,
          passed_partial_dob: true,
          partial_dob_override_enabled: false,
        )
      end

      expect(error_parser).to be
    end
  end

  describe '#parsed_errors' do
    subject(:errors) { error_parser.parsed_errors }

    it 'should return an array of errors from the response' do
      expect(errors[:base]).to start_with('Verification failed with code:')
      expect(errors[:Discovery]).to eq(nil) # This should be absent since it passed
      expect(errors[:SomeOtherProduct]).to eq(response_body['Products'][1])
      expect(errors[:InstantVerify]).to eq(response_body['Products'][2])
    end
  end

  describe '#instant_verify_dob_year_only_pass?' do
    subject(:dob_year_only_pass) do
      error_parser.send(:instant_verify_dob_year_only_pass?, items)
    end

    context 'with both DOBYearVerified and DOBFullVerified passing' do
      let(:items) do
        [
          { 'ItemName' => 'DOBYearVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'SomeOtherProduct', 'ItemStatus' => 'pass' },
        ]
      end
      it { is_expected.to eq(true) }
    end

    context 'with both DOBYearVerified and DOBFullVerified passing' do
      let(:items) do
        [
          { 'ItemName' => 'DOBYearVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'SomeOtherProduct', 'ItemStatus' => 'pass' },
        ]
      end
      it { is_expected.to eq(true) }
    end

    context 'with both DOBYearVerified and DOBFullVerified passing, some other product failing' do
      let(:items) do
        [
          { 'ItemName' => 'DOBYearVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'SomeOtherProduct', 'ItemStatus' => 'fail' },
        ]
      end
      it { is_expected.to be_falsey }
    end

    context 'with both DOBYearVerified passed, and DOBFullVerified failing' do
      let(:items) do
        [
          { 'ItemName' => 'DOBYearVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' },
          { 'ItemName' => 'SomeOtherProduct', 'ItemStatus' => 'pass' },
        ]
      end
      it { is_expected.to eq(true) }
    end

    context 'with DOBYearVerified passed and DOBFullVerified failing, some other product failing' do
      let(:items) do
        [
          { 'ItemName' => 'DOBYearVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' },
          { 'ItemName' => 'SomeOtherProduct', 'ItemStatus' => 'fail' },
        ]
      end
      it { is_expected.to be_falsey }
    end

    context 'with DOBYearVerified missing and DOBFullVerified passing' do
      let(:items) do
        [
          { 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'SomeOtherProduct', 'ItemStatus' => 'pass' },
        ]
      end
      it { is_expected.to be_falsey }
    end

    context 'with DOBYearVerified passing and DOBFullVerified missing' do
      let(:items) do
        [
          { 'ItemName' => 'DOBYearVerified', 'ItemStatus' => 'pass' },
          { 'ItemName' => 'SomeOtherProduct', 'ItemStatus' => 'pass' },
        ]
      end
      it { is_expected.to be_falsey }
    end

    context 'with a nil Items array' do
      let(:items) { nil }
      it { is_expected.to be_falsey }
    end
  end
end

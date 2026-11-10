require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Decorators::InstantVerify::WithMdlOverrides do
  let(:proofer) { instance_double(Proofing::LexisNexis::Ddp::Proofers::InstantVerifyProofer) }
  subject { described_class.new(proofer) }

  describe '#proof' do
    let(:applicant) { { first_name: 'Testing', last_name: 'Testington' } }
    let(:error_code_items) { [] }
    let(:errors) do
      {
        "Execute Instant Verify": [{
          'Items' => error_code_items,
        }],
      }
    end
    let(:success) { false }
    let(:original_result) do
      Proofing::Resolution::Result.new(
        success:,
        errors:,
        exception: nil,
        vendor_name: 'lexisnexis:InstantVerify',
        transaction_id: 'abc123',
        failed_result_can_pass_with_additional_verification: true,
        attributes_requiring_additional_verification: [:address],
        result_overrides: [{ name: 'PreviousOverrides', reason: 'Testing' }],
      )
    end

    before do
      allow(proofer).to receive(:proof).and_return(original_result)
    end

    context 'when the original result is successful' do
      let(:success) { true }

      it 'returns the original result object' do
        expect(subject.proof(applicant)).to be(original_result)
      end
    end

    context 'when the original result is unsuccessful' do
      context 'when the result contains only overridden failures' do
        context 'when the failure is an "occupancy_not_verified_fail" code' do
          let(:error_code_items) do
            [
              {
                'ItemName' => 'IdentityOccupancyVerified',
                'ItemStatus' => 'fail',
                'ItemReason' => {
                  'Code' => 'occupancy_not_verified_fail',
                },
              },
              {
                'ItemName' => 'OtherCheck',
                'ItemStatus' => 'pass',
              },
            ]
          end

          it 'returns a successful result object' do
            expect(subject.proof(applicant)).to have_attributes(
              success: true,
              errors: original_result.errors,
              exception: original_result.exception,
              vendor_name: original_result.vendor_name,
              transaction_id: original_result.transaction_id,
              failed_result_can_pass_with_additional_verification:
                original_result.failed_result_can_pass_with_additional_verification,
              attributes_requiring_additional_verification:
                original_result.attributes_requiring_additional_verification,
              result_overrides: contain_exactly(
                *original_result.result_overrides,
                {
                  name: 'id_resolution_check_override',
                  reason: 'mdl',
                  overrides: [{ IdentityOccupancyVerified: 'occupancy_not_verified_fail' }],
                },
              ),
            )
          end
        end

        context 'when the failure is an "unable_to_find_dl_fail" code' do
          let(:error_code_items) do
            [
              {
                'ItemName' => 'DriversLicense',
                'ItemStatus' => 'fail',
                'ItemReason' => {
                  'Code' => 'unable_to_find_dl_fail',
                },
              },
              {
                'ItemName' => 'OtherCheck',
                'ItemStatus' => 'pass',
              },
            ]
          end

          it 'returns a successful result object' do
            expect(subject.proof(applicant)).to have_attributes(
              success: true,
              errors: original_result.errors,
              exception: original_result.exception,
              vendor_name: original_result.vendor_name,
              transaction_id: original_result.transaction_id,
              failed_result_can_pass_with_additional_verification:
                original_result.failed_result_can_pass_with_additional_verification,
              attributes_requiring_additional_verification:
                original_result.attributes_requiring_additional_verification,
              result_overrides: contain_exactly(
                *original_result.result_overrides,
                {
                  name: 'id_resolution_check_override',
                  reason: 'mdl',
                  overrides: [{ DriversLicense: 'unable_to_find_dl_fail' }],
                },
              ),
            )
          end
        end

        context 'when multiple override failures exist' do
          let(:error_code_items) do
            [
              {
                'ItemName' => 'DriversLicense',
                'ItemStatus' => 'fail',
                'ItemReason' => {
                  'Code' => 'unable_to_find_dl_fail',
                },
              },
              {
                'ItemName' => 'IdentityOccupancyVerified',
                'ItemStatus' => 'fail',
                'ItemReason' => {
                  'Code' => 'occupancy_not_verified_fail',
                },
              },
              {
                'ItemName' => 'OtherCheck',
                'ItemStatus' => 'pass',
              },
            ]
          end

          it 'returns a successful result object' do
            expect(subject.proof(applicant)).to have_attributes(
              success: true,
              errors: original_result.errors,
              exception: original_result.exception,
              vendor_name: original_result.vendor_name,
              transaction_id: original_result.transaction_id,
              failed_result_can_pass_with_additional_verification:
                original_result.failed_result_can_pass_with_additional_verification,
              attributes_requiring_additional_verification:
                original_result.attributes_requiring_additional_verification,
              result_overrides: contain_exactly(
                *original_result.result_overrides,
                {
                  name: 'id_resolution_check_override',
                  reason: 'mdl',
                  overrides: contain_exactly(
                    { IdentityOccupancyVerified: 'occupancy_not_verified_fail' },
                    { DriversLicense: 'unable_to_find_dl_fail' },
                  ),
                },
              ),
            )
          end
        end
      end

      context 'when the result contains additional failures' do
        let(:error_code_items) do
          [
            {
              'ItemName' => 'IdentityOccupancyVerified',
              'ItemStatus' => 'fail',
              'ItemReason' => {
                'Code' => 'occupancy_not_verified_fail',
              },
            },
            {
              'ItemName' => 'IAmError',
              'ItemStatus' => 'fail',
              'ItemReason' => {
                'Code' => 'i_am_error',
              },
            },
          ]
        end

        it 'returns the original result object' do
          expect(subject.proof(applicant)).to be(original_result)
        end
      end

      context 'when no overriden errors are present' do
        let(:error_code_items) do
          [
            {
              'ItemName' => 'IAmError',
              'ItemStatus' => 'fail',
              'ItemReason' => {
                'Code' => 'i_am_error',
              },
            },
            {
              'ItemName' => 'DateOfBirth',
              'ItemStatus' => 'fail',
              'ItemReason' => {
                'Code' => 'does_not_match',
              },
            },
          ]
        end

        it 'returns the original result object' do
          expect(subject.proof(applicant)).to be(original_result)
        end
      end

      context 'when the error code items are not failures' do
        let(:error_code_items) do
          [
            {
              'ItemName' => 'IdentityOccupancyVerified',
              'ItemStatus' => 'failed',
            },
            {
              'ItemName' => 'IAmError',
              'ItemStatus' => 'failed',
            },
          ]
        end

        it 'returns the original result object' do
          expect(subject.proof(applicant)).to be(original_result)
        end
      end

      context 'when the error code items are nil' do
        let(:error_code_items) { nil }

        it 'returns the original result object' do
          expect(subject.proof(applicant)).to be(original_result)
        end
      end

      context 'when the errors is an empty hash' do
        let(:errors) { {} }

        it 'returns the original result object' do
          expect(subject.proof(applicant)).to be(original_result)
        end
      end
    end
  end
end

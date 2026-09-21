require 'json'
require 'event_summarizer/vendor_result_evaluators/phone_finder'

RSpec.describe EventSummarizer::VendorResultEvaluators::PhoneFinder do
  subject(:evaluation) do
    described_class.evaluate_result(
      JSON.parse(JSON.generate(phone_result)),
    )
  end

  describe 'failed result' do
    context 'general failure' do
      let(:phone_result) do
        {
          success: false,
          errors: {
            base: ["Verification failed with code: 'phone_finder_fail'"],
            "PhoneFinder Checks": [
              {
                ProductStatus: 'fail',
                ProductReason: {
                  Description: 'General failure reason',
                },
              },
            ],
          },
        }
      end

      it 'returns the correct result' do
        expect(evaluation).to eql(
          {
            description: 'Phone Finder check failed: General failure reason',
            type: :phone_finder_error,
          },
        )
      end
    end

    context 'itemized failure' do
      let(:phone_result) do
        {
          success: false,
          errors: {
            base: ["Verification failed with code: 'phone_finder_fail'"],
            PhoneFinder: [
              {
                ProductStatus: 'fail',
                Items: [
                  {
                    ItemStatus: 'fail',
                    ItemReason: {
                      Description: 'Specific failure reason A',
                    },
                  },
                  {
                    ItemStatus: 'fail',
                    ItemReason: {
                      Description: 'Specific failure reason B',
                    },
                  },
                ],
              },
            ],
          },
        }
      end

      it 'returns the correct result' do
        expect(evaluation).to eql(
          {
            description: 'Phone Finder check failed: ' \
            'Specific failure reason A; Specific failure reason B',
            type: :phone_finder_error,
          },
        )
      end
    end

    context 'when the lookup succeeded but individual items failed' do
      let(:phone_result) do
        {
          success: false,
          errors: {
            base: ["Verification failed with code: 'phone_finder_fail'"],
            PhoneFinder: [
              {
                ProductType: 'PhoneFinder',
                ProductStatus: 'pass',
                Items: [
                  { ItemName: 'SpoofingPhoneNumber', ItemStatus: 'pass' },
                  {
                    ItemName: 'PrepaidPhoneNumber',
                    ItemStatus: 'fail',
                    ItemReason: {
                      Code: 'PrepaidPhoneNumber.MEDIUM',
                      Description: 'Phone # is a Prepaid Phone',
                    },
                  },
                  {
                    ItemName: 'SubjectDeceased',
                    ItemStatus: 'fail',
                    ItemReason: {
                      Code: 'SubjectDeceased.HIGH',
                      Description: 'Primary Subject associated to the phone is deceased',
                    },
                  },
                ],
              },
            ],
            'PhoneFinder Checks': [
              {
                ProductStatus: 'fail',
                ProductReason: {
                  Code: 'phone_finder_fail',
                  Description: 'Failed - Input phone number could not be verified to name',
                },
              },
            ],
          },
        }
      end

      it 'reports the specific failed checks' do
        expect(evaluation).to eql(
          {
            description: 'Phone Finder check failed: Phone # is a Prepaid Phone; ' \
                         'Primary Subject associated to the phone is deceased',
            type: :phone_finder_error,
          },
        )
      end

      it 'does not fall back to the generic name-verification text' do
        expect(evaluation[:description]).not_to include('could not be verified to name')
      end
    end

    context 'with no itemized reasons' do
      let(:phone_result) do
        {
          success: false,
          errors: {
            PhoneFinder: [
              {
                ProductStatus: 'pass',
                Items: [{ ItemName: 'VOIPPhone', ItemStatus: 'pass' }],
              },
            ],
            'PhoneFinder Checks': [
              {
                ProductStatus: 'fail',
                ProductReason: {
                  Description: 'Failed - Input phone number could not be verified to name',
                },
              },
            ],
          },
        }
      end

      it 'falls back to the general reason' do
        expect(evaluation).to eql(
          {
            description: 'Phone Finder check failed: ' \
                         'Failed - Input phone number could not be verified to name',
            type: :phone_finder_error,
          },
        )
      end
    end

    context 'with nothing usable in the payload' do
      let(:phone_result) do
        { success: false, errors: {} }
      end

      it 'points at the logs' do
        expect(evaluation).to eql(
          {
            description: 'Phone Finder check failed. Review logs for more information.',
            type: :phone_finder_error,
          },
        )
      end
    end
  end
end

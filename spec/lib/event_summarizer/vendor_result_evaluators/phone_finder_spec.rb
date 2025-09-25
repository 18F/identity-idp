require 'json'
require 'event_summarizer/vendor_result_evaluators/phone_finder'

RSpec.describe EventSummarizer::VendorResultEvaluators::PhoneFinder do
  subject(:evaluation) do
    described_class.evaluate_result(
      JSON.parse(JSON.generate(phone_finder_result)),
    )
  end

  describe 'failed result' do
    context 'general failure' do
      let(:phone_finder_result) do
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
      let(:phone_finder_result) do
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
  end
end

require 'json'
require 'event_summarizer/vendor_result_evaluators/phone_finder'

RSpec.describe EventSummarizer::VendorResultEvaluators::PhoneFinder do
  subject(:evaluation) do
    described_class.evaluate_result(
      JSON.parse(JSON.generate(phone_result)),
    )
  end

  let(:phone_result) do
    {
      success: false,
      errors: errors,
    }
  end

  let(:verdict) do
    {
      ProductStatus: 'fail',
      ProductReason: {
        Description: 'Failed - Input phone number could not be verified to name',
      },
    }
  end

  let(:itemized_reasons) do
    {
      ProductStatus: 'pass',
      Items: [
        {
          ItemName: 'SpoofingPhoneNumber',
          ItemStatus: 'pass',
        },
        {
          ItemName: 'SubjectDeceased',
          ItemStatus: 'fail',
          ItemReason: {
            Description: 'Primary Subject associated to the phone is deceased',
          },
        },
      ],
    }
  end

  describe 'failed result' do
    context 'with a verdict and itemized reasons' do
      let(:errors) do
        {
          PhoneFinder: [itemized_reasons],
          'PhoneFinder Checks': [verdict],
        }
      end

      it 'reports the verdict, then the reasons behind it' do
        expect(evaluation).to eql(
          {
            description: 'Phone Finder check failed: ' \
                         'Failed - Input phone number could not be verified to name; ' \
                         'Primary Subject associated to the phone is deceased',
            type: :phone_finder_error,
          },
        )
      end
    end

    context 'with a verdict and no itemized reasons' do
      let(:errors) do
        {
          'PhoneFinder Checks': [verdict],
        }
      end

      it 'reports the verdict' do
        expect(evaluation).to eql(
          {
            description: 'Phone Finder check failed: ' \
                         'Failed - Input phone number could not be verified to name',
            type: :phone_finder_error,
          },
        )
      end
    end

    context 'with itemized reasons and no verdict' do
      let(:errors) do
        {
          PhoneFinder: [itemized_reasons],
        }
      end

      it 'reports the reasons' do
        expect(evaluation).to eql(
          {
            description: 'Phone Finder check failed: ' \
                         'Primary Subject associated to the phone is deceased',
            type: :phone_finder_error,
          },
        )
      end
    end

    context 'with nothing to explain the failure' do
      let(:errors) do
        {}
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

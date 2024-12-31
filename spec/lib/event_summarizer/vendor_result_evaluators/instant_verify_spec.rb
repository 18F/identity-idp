require 'json'
require 'event_summarizer/vendor_result_evaluators/instant_verify'

RSpec.describe EventSummarizer::VendorResultEvaluators::InstantVerify do
  let(:instant_verify_result) do
    {
      success: true,
      errors: {},
      exception: nil,
      timed_out: false,
    }
  end

  subject(:evaluation) do
    described_class.evaluate_result(
      JSON.parse(JSON.generate(instant_verify_result)),
    )
  end

  context 'successful result' do
    it 'looks correct' do
      expect(evaluation).to eql(
        {
          type: :instant_verify_success,
          description: 'Instant Verify call succeeded',
        },
      )
    end
  end

  context 'request timed out' do
    let(:instant_verify_result) do
      super().merge(
        success: false,
        errors: {},
        timed_out: true,
      )
    end

    it 'reports the error appropriately' do
      expect(evaluation).to eql(
        {
          type: :instant_verify_timed_out,
          description: 'Instant Verify request timed out.',
        },
      )
    end
  end

  context 'failed result' do
    let(:instant_verify_result) do
      {
        success: false,
        errors: {
          base: ["Verification failed with code: 'priority.scoring.model.verification.fail'"],
          InstantVerify: [
            {
              ProductType: 'InstantVerify',
              ExecutedStepName: 'InstantVerify',
              ProductConfigurationName: 'blah.config',
              ProductStatus: 'fail',
              ProductReason: {
                Code: 'priority.scoring.model.verification.fail',
              },
              Items: [
                { ItemName: 'Check1', ItemStatus: 'pass' },
                { ItemName: 'Check2', ItemStatus: 'fail' },
                {
                  ItemName: 'CheckWithCode',
                  ItemStatus: 'fail',
                  ItemReason: { Code: 'some_obscure_code ' },
                },
              ],
            },
          ],
        },
        exception: nil,
        timed_out: false,
      }
    end

    it 'returns the correct result' do
      expect(evaluation).to eql(
        {
          description: 'Instant Verify request failed. 2 checks failed: Check2, CheckWithCode (some_obscure_code )',
          type: :instant_verify_error,
        },
      )
    end
  end
end

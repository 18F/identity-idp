require 'json'
require 'event_summarizer/vendor_result_evaluators/aamva'

RSpec.describe EventSummarizer::VendorResultEvaluators::Aamva do
  let(:aamva_result) do
    {
      success: true,
      errors: {},
      exception: nil,
      timed_out: false,
      mva_exception: false,
      state_id_jurisdiction: 'MD',
      document_type_received: 'drivers_license',
    }
  end

  subject(:evaluation) do
    described_class.evaluate_result(
      JSON.parse(JSON.generate(aamva_result)),
    )
  end

  context 'successful result' do
    it 'looks correct' do
      expect(evaluation).to eql(
        {
          type: :aamva_success,
          description: 'AAMVA call succeeded',
        },
      )
    end
  end

  context 'request timed out' do
    let(:aamva_result) { super().merge(success: false, timed_out: true) }

    it 'reports the timeout' do
      expect(evaluation).to eql(
        {
          type: :aamva_timed_out,
          description: 'AAMVA request timed out.',
        },
      )
    end
  end

  context 'the state MVA failed to respond' do
    let(:aamva_result) { super().merge(success: false, mva_exception: true) }

    it 'names the state' do
      expect(evaluation).to eql(
        {
          type: :aamva_mva_exception,
          description: 'AAMVA request failed because the MVA in MD failed to return a response.',
        },
      )
    end
  end

  describe 'attribute mismatches' do
    context 'when the MVA could not find the ID number at all' do
      # Everything except the ID number comes back MISSING: the MVA had no record to compare.
      let(:aamva_result) do
        super().merge(
          success: false,
          errors: {
            state_id_number: ['UNVERIFIED'],
            dob: ['MISSING'],
            last_name: ['MISSING'],
          },
        )
      end

      it 'says the ID number was invalid according to the state' do
        expect(evaluation[:type]).to eql(:aamva_error)
        expect(evaluation[:description]).to eql(
          "AAMVA request failed. The ID # from the user's drivers' license was invalid " \
          "according to the state of MD",
        )
      end
    end

    context 'when an UNVERIFIED attribute is outside the required lists' do
      # Regression: state_id_issued and address1 were dropped entirely, so a summary reported
      # "1 attribute failed to validate" when the state had in fact rejected three.
      let(:aamva_result) do
        super().merge(
          success: false,
          errors: {
            state_id_number: ['UNVERIFIED'],
            state_id_issued: ['UNVERIFIED'],
            address1: ['UNVERIFIED'],
            height: ['MISSING'],
            sex: ['MISSING'],
          },
        )
      end

      it 'reports every mismatched attribute, required ones first' do
        expect(evaluation[:description]).to eql(
          'AAMVA request failed. 3 attributes failed to validate: ' \
          'state_id_number, state_id_issued, address1',
        )
      end

      it 'does not report MISSING attributes we never sent' do
        expect(evaluation[:description]).not_to include('height')
        expect(evaluation[:description]).not_to include('sex')
      end
    end

    context 'when a required attribute is MISSING' do
      # Proofing::Aamva::Proofer#successful? requires an affirmative match on these, so MISSING
      # is a failure and worth naming.
      let(:aamva_result) do
        super().merge(
          success: false,
          errors: {
            first_name: ['MISSING'],
            address2: ['MISSING'],
          },
        )
      end

      it 'reports the required attribute and not the optional one' do
        expect(evaluation[:description]).to eql(
          'AAMVA request failed. 1 attribute failed to validate: first_name',
        )
      end
    end

    context 'with a single mismatch' do
      let(:aamva_result) do
        super().merge(success: false, errors: { dob: ['UNVERIFIED'] })
      end

      it 'uses the singular' do
        expect(evaluation[:description]).to eql(
          'AAMVA request failed. 1 attribute failed to validate: dob',
        )
      end
    end

    context 'when there is no usable explanation' do
      let(:aamva_result) { super().merge(success: false, errors: {}) }

      it 'falls back to pointing at the logs' do
        expect(evaluation).to eql(
          {
            type: :aamva_error,
            description: 'AAMVA request failed. Check logs for more info.',
          },
        )
      end
    end

    context 'when errors is absent entirely' do
      let(:aamva_result) { super().merge(success: false, errors: nil) }

      it 'falls back rather than raising' do
        expect { evaluation }.not_to raise_error
        expect(evaluation).to eql(
          {
            type: :aamva_error,
            description: 'AAMVA request failed. Check logs for more info.',
          },
        )
      end
    end
  end
end

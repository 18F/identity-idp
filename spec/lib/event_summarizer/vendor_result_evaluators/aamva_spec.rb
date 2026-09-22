require 'json'
require 'event_summarizer/vendor_result_evaluators/aamva'

RSpec.describe EventSummarizer::VendorResultEvaluators::Aamva do
  let(:success) { true }
  let(:errors) { {} }
  let(:exception) { nil }
  let(:timed_out) { false }
  let(:mva_exception) { false }
  let(:state_id_jurisdiction) { 'MD' }
  let(:document_type_received) { 'drivers_license' }

  let(:aamva_result) do
    {
      success:,
      errors:,
      exception:,
      timed_out:,
      mva_exception:,
      state_id_jurisdiction:,
      document_type_received:,
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
    let(:success) { false }
    let(:timed_out) { true }

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
    let(:success) { false }
    let(:mva_exception) { true }

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
    let(:success) { false }

    context 'when the MVA has no record of the ID number' do
      let(:errors) do
        {
          state_id_number: ['UNVERIFIED'],
          dob: ['MISSING'],
          last_name: ['MISSING'],
        }
      end

      it 'says the ID number was invalid according to the state' do
        expect(evaluation[:type]).to eql(:aamva_error)
        expect(evaluation[:description]).to eql(
          "AAMVA request failed. The ID # from the user's drivers' license was invalid " \
          "according to the state of MD",
        )
      end
    end

    context 'when attributes outside the required lists are UNVERIFIED' do
      let(:errors) do
        {
          state_id_number: ['UNVERIFIED'],
          state_id_issued: ['UNVERIFIED'],
          address1: ['UNVERIFIED'],
          height: ['MISSING'],
          sex: ['MISSING'],
        }
      end

      it 'reports every mismatched attribute, blocking ones first' do
        expect(evaluation[:description]).to eql(
          'AAMVA request failed. 3 attributes failed to validate: ' \
          'state_id_number, state_id_issued, address1',
        )
      end

      it 'does not report MISSING attributes that were never sent' do
        expect(evaluation[:description]).not_to include('height')
        expect(evaluation[:description]).not_to include('sex')
      end
    end

    context 'when an expired ID is what failed the request' do
      let(:errors) do
        {
          state_id_expiration: ['UNVERIFIED'],
          address1: ['UNVERIFIED'],
        }
      end

      it 'lists the expiration ahead of attributes that cannot fail the request' do
        expect(evaluation[:description]).to eql(
          'AAMVA request failed. 2 attributes failed to validate: ' \
          'state_id_expiration, address1',
        )
      end
    end

    context 'when the ID was sent without an expiration date' do
      let(:errors) do
        {
          state_id_expiration: ['MISSING'],
          address1: ['UNVERIFIED'],
        }
      end

      it 'leaves it out, because #successful? accepts it MISSING' do
        expect(evaluation[:description]).to eql(
          'AAMVA request failed. 1 attribute failed to validate: address1',
        )
      end
    end

    context 'when a required attribute is MISSING' do
      let(:errors) do
        {
          first_name: ['MISSING'],
          address2: ['MISSING'],
        }
      end

      it 'reports the required attribute and not the optional one' do
        expect(evaluation[:description]).to eql(
          'AAMVA request failed. 1 attribute failed to validate: first_name',
        )
      end
    end

    context 'with a single mismatch' do
      let(:errors) do
        { dob: ['UNVERIFIED'] }
      end

      it 'uses the singular' do
        expect(evaluation[:description]).to eql(
          'AAMVA request failed. 1 attribute failed to validate: dob',
        )
      end
    end

    context 'when there are no errors to explain' do
      let(:errors) do
        {}
      end

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
      let(:errors) { nil }

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

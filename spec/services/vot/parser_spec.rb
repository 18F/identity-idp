require 'rails_helper'

RSpec.describe Vot::Parser do
  describe '#parse' do
    context 'when neither a VtR nor ACR values are provided' do
      it 'raises an error' do
        expect { Vot::Parser.new(vector_of_trust: nil, acr_values: nil).parse }.
          to raise_error(Vot::Parser::ParseException, 'VoT parser called without VoT or ACR values')
      end
    end

    context 'when a vector is completely expanded' do
      it 'returns the vector along with requirements' do
        vector_of_trust = 'C1.C2.Cb'

        result = Vot::Parser.new(vector_of_trust:).parse

        expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.Cb')
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(true)
        expect(result.identity_proofing?).to eq(false)
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end
    end

    context 'when a component value has implied components' do
      it 'adds the implied components' do
        vector_of_trust = 'Pb'

        result = Vot::Parser.new(vector_of_trust:).parse

        expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pb')
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(true)
        expect(result.biometric_comparison?).to eq(true)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      it 'adds the Enhanced In Person Proofing components' do
        vector_of_trust = 'Pe'

        result = Vot::Parser.new(vector_of_trust:).parse

        expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pe')
        expect(result.enhanced_ipp?).to eq(true)
      end
    end

    it 'adds the two pieces of fair evidence components' do
      vector_of_trust = 'Pb'

      result = Vot::Parser.new(vector_of_trust:).parse

      expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pb')
      expect(result.two_pieces_of_fair_evidence?).to eq(true)
    end

    context 'when a vector includes unrecognized components' do
      it 'raises an exception' do
        vector_of_trust = 'C1.C2.Xx'

        expect { Vot::Parser.new(vector_of_trust:).parse }.to raise_exception(
          Vot::Parser::ParseException,
          'C1.C2.Xx contains unkown component Xx',
        )
      end
    end

    context 'when a vector include duplicate components' do
      it 'raises an exception' do
        vector_of_trust = 'C1.C1'
        expect { Vot::Parser.new(vector_of_trust:).parse }.to raise_exception(
          Vot::Parser::ParseException,
          'C1.C1 contains duplicate components',
        )
      end

      context 'when ACR values are provided' do
        it 'parses ACR values to component values' do
          acr_values = [
            'http://idmanagement.gov/ns/assurance/aal/2?hspd12=true',
            'http://idmanagement.gov/ns/assurance/ial/2',
          ].join(' ')

          result = Vot::Parser.new(acr_values:).parse

          expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
          expect(result.aal2?).to eq(true)
          expect(result.phishing_resistant?).to eq(false)
          expect(result.hspd12?).to eq(true)
          expect(result.identity_proofing?).to eq(true)
          expect(result.biometric_comparison?).to eq(false)
          expect(result.ialmax?).to eq(false)
          expect(result.enhanced_ipp?).to eq(false)
        end
      end
    end
  end
end

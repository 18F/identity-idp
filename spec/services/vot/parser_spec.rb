require 'rails_helper'

RSpec.describe Vot::Parser do
  describe '#parse' do
    context 'when a vector is completely expanded' do
      it 'returns the vector along with requirements' do
        vector_of_trust = 'C1.C2.Cb'

        result = Vot::Parser.new(vector_of_trust).parse

        expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.Cb')
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(true)
        expect(result.identity_proofing?).to eq(false)
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
      end
    end

    context 'when a component value has implied components' do
      it 'adds the implied components' do
        vector_of_trust = 'Pb'

        result = Vot::Parser.new(vector_of_trust).parse

        expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pb')
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(true)
        expect(result.biometric_comparison?).to eq(true)
        expect(result.ialmax?).to eq(false)
      end
    end

    context 'when a vector includes unrecognized components' do
      it 'raises an exception' do
        vector_of_trust = 'C1.C2.Xx'

        expect { Vot::Parser.new(vector_of_trust).parse }.to raise_exception(
          Vot::Parser::ParseException,
          'C1.C2.Xx contains unkown component Xx',
        )
      end
    end

    context 'when a vector include duplicate components' do
      it 'raises an exception' do
        vector_of_trust = 'C1.C1'
        expect { Vot::Parser.new(vector_of_trust).parse }.to raise_exception(
          Vot::Parser::ParseException,
          'C1.C1 contains duplicate components',
        )
      end
    end
  end

  describe '#parse_acr' do
    it 'parsed ACR values to component values' do
      vector_of_trust = [
        'http://idmanagement.gov/ns/assurance/aal/2?hspd12=true',
        'http://idmanagement.gov/ns/assurance/ial/2',
      ].join(' ')

      result = Vot::Parser.new(vector_of_trust).parse_acr

      expect(result.component_values.map(&:name).join(' ')).to eq(vector_of_trust)
      expect(result.aal2?).to eq(true)
      expect(result.phishing_resistant?).to eq(false)
      expect(result.hspd12?).to eq(true)
      expect(result.identity_proofing?).to eq(true)
      expect(result.biometric_comparison?).to eq(false)
      expect(result.ialmax?).to eq(false)
    end
  end
end

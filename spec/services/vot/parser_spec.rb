require 'rails_helper'

RSpec.describe Vot::Parser do
  context 'when a vector is completely expanded' do
    it 'returns the vector along with requirements' do
      vector_of_trust = 'C1.C2.Cb'

      result = Vot::Parser.new(vector_of_trust).parse

      expect(result.vector_of_trust).to eq('C1.C2.Cb')
      expect(result.aal2).to eq(true)
      expect(result.phishing_resistant).to eq(false)
      expect(result.hspd12).to eq(true)
      expect(result.identity_proofing).to eq(false)
      expect(result.biometric_comparison).to eq(false)
    end
  end

  context 'when a component value has implied components' do
    it 'adds the implied components' do
      vector_of_trust = 'Pb'

      result = Vot::Parser.new(vector_of_trust).parse

      expect(result.vector_of_trust).to eq('C1.C2.P1.Pb')
      expect(result.aal2).to eq(true)
      expect(result.phishing_resistant).to eq(false)
      expect(result.hspd12).to eq(false)
      expect(result.identity_proofing).to eq(true)
      expect(result.biometric_comparison).to eq(true)
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

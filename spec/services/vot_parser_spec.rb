require 'rails_helper'

RSpec.describe VotParser do
  context 'with a VoT with both components' do
    it 'returns a properly mapped result' do
      result = VotParser.new('P1.C2').parse_vot

      expect(result.identity_proofing).to eq(:identity_proofing_no_biometric)
      expect(result.credential_usage).to eq(:unphishable_mfa)
    end

    it 'raises an exception if a component value is not supported' do
      expect { VotParser.new('P1.C2.D3').parse_vot }.to raise_exception(
        VotParser::VotParseException,
        'P1.C2.D3 contains unsupported component D',
      )
    end
  end

  context 'with a VoT with only a P component' do
    it 'returns a properly mapped result' do
      result = VotParser.new('P2').parse_vot

      expect(result.identity_proofing).to eq(:identity_proofing_biometric_required)
      expect(result.credential_usage).to eq(:default)
    end

    it 'raises an exception if the P component value is not supported' do
      expect { VotParser.new('Px').parse_vot }.to raise_exception(
        VotParser::VotParseException,
        'Px contains unsupported P value x',
      )
    end
  end

  context 'with a VoT with only a C component' do
    it 'returns a properly mapped result' do
      result = VotParser.new('C1').parse_vot

      expect(result.identity_proofing).to eq(:no_identity_proofing)
      expect(result.credential_usage).to eq(:no_remember_device)
    end

    it 'raises an exception if the C component value is not supported'  do
      expect { VotParser.new('Cx').parse_vot }.to raise_exception(
        VotParser::VotParseException,
        'Cx contains unsupported C value x',
      )
    end
  end

  context 'with an empty VoT' do
    it 'returns a result mapped to both default values' do
      result = VotParser.new('').parse_vot

      expect(result.identity_proofing).to eq(:no_identity_proofing)
      expect(result.credential_usage).to eq(:default)
    end
  end

  context 'with an improperly formatted VoT' do
    it 'raises an exception' do
      expect { VotParser.new('this_is_not_valid').parse_vot }.to raise_exception(
        VotParser::VotParseException,
        'this_is_not_valid is not a valid VoT',
      )
    end
  end
end

require 'rails_helper'

describe Pii::Fingerprinter do
  describe '#fingerprint' do
    it 'returns a 256 bit string' do
      fingerprint = described_class.fingerprint(SecureRandom.uuid)

      expect(fingerprint).to be_a String
      expect(fingerprint.length).to eq 64
      expect(fingerprint.hex).to be_a Integer
    end
  end
end

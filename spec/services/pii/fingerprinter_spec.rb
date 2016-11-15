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

  describe '#verify' do
    it 'returns true for identical fingerprints' do
      text = SecureRandom.uuid
      fingerprint = described_class.fingerprint(text)

      expect(described_class.verify(text, fingerprint)).to eq true
    end

    it 'returns false for unequal fingerprints' do
      fingerprint = described_class.fingerprint('foo')

      expect(described_class.verify('bar', fingerprint)).to eq false
    end
  end
end

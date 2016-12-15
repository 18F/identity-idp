require 'rails_helper'

describe Pii::Fingerprinter do
  before do
    allow(Figaro.env).to receive(:hmac_fingerprinter_key_queue).and_return(
      '["old-key-one", "old-key-two"]'
    )
  end

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

    it 'returns true for old key' do
      text = SecureRandom.uuid
      fingerprint = described_class.fingerprint(text, 'old-key-two')

      expect(described_class.verify(text, fingerprint)).to eq true
    end
  end

  describe '#verify_current' do
    it 'returns true for identical fingerprints' do
      text = SecureRandom.uuid
      fingerprint = described_class.fingerprint(text)

      expect(described_class.verify_current(text, fingerprint)).to eq true
    end

    it 'returns false for unequal fingerprints' do
      fingerprint = described_class.fingerprint('foo')

      expect(described_class.verify_current('bar', fingerprint)).to eq false
    end
  end

  describe '#verify_queue' do
    it 'returns true for old key' do
      text = SecureRandom.uuid
      fingerprint = described_class.fingerprint(text, 'old-key-two')

      expect(described_class.verify_queue(text, fingerprint)).to eq true
    end

    it 'returns false for unequal fingerprints' do
      fingerprint = described_class.fingerprint('foo', 'old-key-two')

      expect(described_class.verify_queue('bar', fingerprint)).to eq false
    end
  end

  describe '#stale?' do
    it 'returns true if hashed with old key' do
      text = SecureRandom.uuid
      fingerprint = described_class.fingerprint(text, 'old-key-two')

      expect(described_class.stale?(text, fingerprint)).to eq true
    end

    it 'return false if hashed with current key' do
      text = SecureRandom.uuid
      fingerprint = described_class.fingerprint(text)

      expect(described_class.stale?(text, fingerprint)).to eq false
    end
  end
end

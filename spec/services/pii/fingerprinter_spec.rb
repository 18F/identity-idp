require 'rails_helper'

RSpec.describe Pii::Fingerprinter do
  before do
    allow(IdentityConfig.store).to receive(:hmac_fingerprinter_key_queue).and_return(
      ['old-key-one', 'old-key-two'],
    )
  end

  describe '#fingerprint' do
    it 'returns a 256 bit string' do
      fingerprint = Pii::Fingerprinter.fingerprint(SecureRandom.uuid)

      expect(fingerprint).to be_a String
      expect(fingerprint.length).to eq 64
      expect(fingerprint.hex).to be_a Integer
    end
  end

  describe '#verify' do
    it 'returns true for identical fingerprints' do
      text = SecureRandom.uuid
      fingerprint = Pii::Fingerprinter.fingerprint(text)

      expect(Pii::Fingerprinter.verify(text, fingerprint)).to eq true
    end

    it 'returns false for unequal fingerprints' do
      fingerprint = Pii::Fingerprinter.fingerprint('foo')

      expect(Pii::Fingerprinter.verify('bar', fingerprint)).to eq false
    end

    it 'returns true for old key' do
      text = SecureRandom.uuid
      fingerprint = Pii::Fingerprinter.fingerprint(text, 'old-key-two')

      expect(Pii::Fingerprinter.verify(text, fingerprint)).to eq true
    end
  end

  describe '#verify_current' do
    it 'returns true for identical fingerprints' do
      text = SecureRandom.uuid
      fingerprint = Pii::Fingerprinter.fingerprint(text)

      expect(Pii::Fingerprinter.verify_current(text, fingerprint)).to eq true
    end

    it 'returns false for unequal fingerprints' do
      fingerprint = Pii::Fingerprinter.fingerprint('foo')

      expect(Pii::Fingerprinter.verify_current('bar', fingerprint)).to eq false
    end
  end

  describe '#verify_queue' do
    it 'returns true for old key' do
      text = SecureRandom.uuid
      fingerprint = Pii::Fingerprinter.fingerprint(text, 'old-key-two')

      expect(Pii::Fingerprinter.verify_queue(text, fingerprint)).to eq true
    end

    it 'returns false for unequal fingerprints' do
      fingerprint = Pii::Fingerprinter.fingerprint('foo', 'old-key-two')

      expect(Pii::Fingerprinter.verify_queue('bar', fingerprint)).to eq false
    end
  end

  describe '#stale?' do
    it 'returns true if hashed with old key' do
      text = SecureRandom.uuid
      fingerprint = Pii::Fingerprinter.fingerprint(text, 'old-key-two')

      expect(Pii::Fingerprinter.stale?(text, fingerprint)).to eq true
    end

    it 'return false if hashed with current key' do
      text = SecureRandom.uuid
      fingerprint = Pii::Fingerprinter.fingerprint(text)

      expect(Pii::Fingerprinter.stale?(text, fingerprint)).to eq false
    end

    it 'returns true if the fingerprint is nil and the text is not' do
      text = SecureRandom.uuid
      fingerprint = nil

      expect(Pii::Fingerprinter.stale?(text, fingerprint)).to eq true
    end
  end
end

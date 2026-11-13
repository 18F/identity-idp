require 'rails_helper'

RSpec.describe SiteKeys::RecoveryCode do
  describe '.generate' do
    it 'returns a code in the personal key format' do
      expect(described_class.generate).to match(/\A[0-9A-Z]{4}(-[0-9A-Z]{4}){3}\z/)
    end
  end

  describe '.normalize' do
    it 'ignores case and separators' do
      code = described_class.generate

      expect(described_class.normalize(code.downcase.tr('-', ' ')))
        .to eq(described_class.normalize(code))
    end

    it 'returns nil for a malformed code' do
      expect(described_class.normalize('too short')).to be_nil
    end

    it 'returns nil for characters outside the alphabet' do
      expect(described_class.normalize('UUUU-UUUU-UUUU-UUUU')).to be_nil
    end
  end
end

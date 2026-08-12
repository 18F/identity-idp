# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pii::CurrentAddressMatchesId do
  describe '.coerce' do
    it 'returns nil for nil' do
      expect(described_class.coerce(nil)).to be_nil
    end

    it 'returns booleans unchanged' do
      expect(described_class.coerce(true)).to eq(true)
      expect(described_class.coerce(false)).to eq(false)
    end

    it 'coerces the legacy string values' do
      expect(described_class.coerce('true')).to eq(true)
      expect(described_class.coerce('false')).to eq(false)
    end
  end

  describe '.read' do
    it 'returns nil when neither field is present' do
      expect(described_class.read({})).to be_nil
    end

    it 'prefers the new boolean field' do
      expect(described_class.read(ipp_current_address_matches_id: true)).to eq(true)
      expect(described_class.read(ipp_current_address_matches_id: false)).to eq(false)
    end

    it 'falls back to the legacy string field when the new field is absent' do
      expect(described_class.read(same_address_as_id: 'true')).to eq(true)
      expect(described_class.read(same_address_as_id: 'false')).to eq(false)
    end

    it 'prefers the new field even when the legacy field disagrees' do
      expect(
        described_class.read(
          ipp_current_address_matches_id: true,
          same_address_as_id: 'false',
        ),
      ).to eq(true)
    end
  end
end

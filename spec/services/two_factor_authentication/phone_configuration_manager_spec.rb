require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PhoneConfigurationManager do
  let(:subject) { described_class.new(user) }

  context 'with a phone configured' do
    let(:user) { build(:user, :with_phone) }

    it 'is enabled' do
      expect(subject.enabled?).to eq true
    end

    it 'is configured' do
      expect(subject.configured?).to eq true
    end

    it 'is available' do
      expect(subject.available?).to eq true
    end

    it 'is not configurable' do
      expect(subject.configurable?).to eq false
    end

    describe '#phone' do
      it 'returns the configured phone' do
        expect(subject.phone).to eq user.phone
      end
    end
  end

  context 'with no phone configured' do
    let(:user) { build(:user) }

    it 'is not enabled' do
      expect(subject.enabled?).to eq false
    end

    it 'is not configured' do
      expect(subject.configured?).to eq false
    end

    it 'is available' do
      expect(subject.available?).to eq true
    end

    it 'is configurable' do
      expect(subject.configurable?).to eq true
    end

    describe '#phone' do
      it 'returns nothing' do
        expect(subject.phone).to be nil
      end
    end
  end
end

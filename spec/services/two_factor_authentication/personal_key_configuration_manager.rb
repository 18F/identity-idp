require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PersonalKeyConfigurationManager do
  let(:subject) { described_class.new(user) }

  context 'with a personal key configured' do
    let(:user) { build(:user, :with_personal_key) }

    it 'is enabled' do
      expect(subject.enabled?).to eq true
    end

    it 'is configured' do
      expect(subject.configured?).to eq true
    end

    it 'is not configurable' do
      expect(subject.configurable?).to eq false
    end

    describe '#should_acknowledge?' do
      context 'with session that has personal_key' do
        it 'is true' do
          expect(subject.should_acknowledge?(personal_key: 'foo')).to eq true
        end
      end

      context 'with session that has no personal_key but an sp session with loa3=false' do
        it 'is false' do
          expect(subject.should_acknowledge?(sp: { loa3: false })).to eq false
        end
      end

      context 'with session that has no personal_key and an sp session with loa3=true' do
        it 'is false' do
          expect(subject.should_acknowledge?(sp: { loa3: true })).to eq false
        end
      end
    end
  end

  context 'with no personal key configured' do
    let(:user) { build(:user) }

    it 'is not enabled' do
      expect(subject.enabled?).to eq false
    end

    it 'is not configured' do
      expect(subject.configured?).to eq false
    end

    it 'is not configurable' do
      expect(subject.configurable?).to eq false
    end

    describe '#should_acknowledge?' do
      context 'with session that has personal_key' do
        it 'is true' do
          expect(subject.should_acknowledge?(personal_key: 'foo')).to eq true
        end
      end

      context 'with session that has no personal_key but an sp session with loa3=false' do
        it 'is false' do
          expect(subject.should_acknowledge?(sp: { loa3: false })).to eq true
        end
      end

      context 'with session that has no personal_key and an sp session with loa3=true' do
        it 'is false' do
          expect(subject.should_acknowledge?(sp: { loa3: true })).to eq false
        end
      end
    end
  end
end

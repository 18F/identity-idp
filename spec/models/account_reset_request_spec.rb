require 'rails_helper'

describe AccountResetRequest do
  it { is_expected.to belong_to(:user) }

  let(:subject) { AccountResetRequest.new }

  describe '#granted_token_valid?' do
    it 'returns false if the token does not exist' do
      subject.granted_token = nil
      subject.granted_at = Time.zone.now

      expect(subject.granted_token_valid?).to eq(false)
    end

    it 'returns false if the token is expired' do
      subject.granted_token = '123'
      subject.granted_at = Time.zone.now - 7.days

      expect(subject.granted_token_valid?).to eq(false)
    end

    it 'returns true if the token is valid' do
      subject.granted_token = '123'
      subject.granted_at = Time.zone.now

      expect(subject.granted_token_valid?).to eq(true)
    end
  end

  describe '#granted_token_expired?' do
    it 'returns false if the token does not exist' do
      subject.granted_token = nil
      subject.granted_at = nil

      expect(subject.granted_token_expired?).to eq(false)
    end

    it 'returns true if the token is expired' do
      subject.granted_token = '123'
      subject.granted_at = Time.zone.now - 7.days

      expect(subject.granted_token_expired?).to eq(true)
    end

    it 'returns false if the token is valid' do
      subject.granted_token = '123'
      subject.granted_at = Time.zone.now

      expect(subject.granted_token_expired?).to eq(false)
    end
  end
end

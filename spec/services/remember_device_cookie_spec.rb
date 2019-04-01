require 'rails_helper'

describe RememberDeviceCookie do
  let(:remember_device_revoked_at) { nil }
  let(:user) { create(:user, :with_phone, remember_device_revoked_at: remember_device_revoked_at) }
  let(:created_at) { Time.zone.now }

  subject { described_class.new(user_id: user.id, created_at: created_at) }

  describe '.from_json(json)' do
    it 'should parse a JSON string' do
      json = {
        user_id: 1,
        created_at: created_at.iso8601,
        role: 'remember_me',
        entropy: '123abc',
      }.to_json
      subject = described_class.from_json(json)

      expect(subject.user_id).to eq(1)
      expect(subject.created_at.iso8601).to eq(created_at.iso8601)
    end

    it 'should raise an error if the role in the JSON string is not "remember_me"' do
      json = {
        user_id: 1,
        created_at: created_at.iso8601,
        role: 'something_else',
        entropy: '123abc',
      }.to_json

      expect { described_class.from_json(json) }.to raise_error(
        RuntimeError,
        "RememberDeviceCookie role 'something_else' did not match 'remember_me'",
      )
    end

    it 'should raise an error if the role in the JSON string is missing' do
      json = {
        user_id: 1,
        created_at: created_at.iso8601,
        entropy: '123abc',
      }.to_json

      expect { described_class.from_json(json) }.to raise_error(
        RuntimeError,
        "RememberDeviceCookie role '' did not match 'remember_me'",
      )
    end
  end

  describe '#to_json' do
    it 'should render a JSON string' do
      json = subject.to_json
      parsed_json = JSON.parse(json)

      expect(parsed_json['user_id']).to eq(user.id)
      expect(parsed_json['created_at']).to eq(created_at.iso8601)
      expect(parsed_json['role']).to eq('remember_me')
      expect(parsed_json['entropy']).to_not be_nil
    end
  end

  describe '#valid_for?(user:, expiration_interval:)' do
    let(:expiration_interval) { 30.days }

    subject do
      cookie = described_class.new(user_id: user.id, created_at: created_at)
      cookie.valid_for_user?(user: user, expiration_interval: expiration_interval)
    end

    context 'when the token is valid' do
      it { expect(subject).to eq(true) }
    end

    context 'when the token is expired' do
      let(:created_at) { (expiration_interval + 1).days.ago }

      it { expect(subject).to eq(false) }
    end

    context 'when the token does not refer to the current user' do
      it 'returns false' do
        other_user = create(:user, :with_phone, with: { confirmed_at: 90.days.ago })
        cookie = described_class.new(user_id: user.id, created_at: created_at)

        expect(
          cookie.valid_for_user?(user: other_user, expiration_interval: expiration_interval),
        ).to eq(false)
      end
    end

    context 'when the user revoked remember device after creating the token' do
      let(:created_at) { 5.days.ago }
      let(:remember_device_revoked_at) { 4.days.ago }

      it { expect(subject).to eq(false) }
    end

    context 'when the user revoked remember device before creating the token' do
      let(:created_at) { 5.days.ago }
      let(:remember_device_revoked_at) { 6.days.ago }

      it { expect(subject).to eq(true) }
    end
  end
end

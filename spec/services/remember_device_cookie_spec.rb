require 'rails_helper'

describe RememberDeviceCookie do
  let(:phone_confirmed_at) { 90.days.ago }
  let(:user) { create(:user, phone_confirmed_at: phone_confirmed_at) }
  let(:created_at) { Time.zone.now }

  subject { described_class.new(user_id: user.id, created_at: created_at) }

  describe '.from_json(json)' do
    it 'should parse a JSON string' do
      json = {
        user_id: 1,
        created_at: created_at.iso8601,
      }.to_json
      subject = described_class.from_json(json)

      expect(subject.user_id).to eq(1)
      expect(subject.created_at.iso8601).to eq(created_at.iso8601)
    end
  end

  describe '#to_json' do
    it 'should render a JSON string' do
      json = subject.to_json
      parsed_json = JSON.parse(json)

      expect(parsed_json['user_id']).to eq(user.id)
      expect(parsed_json['created_at']).to eq(created_at.iso8601)
    end
  end

  describe '#valid_for_user?(user)' do
    context 'when the token is valid' do
      it { expect(subject.valid_for_user?(user)).to eq(true) }
    end

    context 'when the token is expired' do
      let(:created_at) { (Figaro.env.remember_device_expiration_days.to_i + 1).days.ago }

      it { expect(subject.valid_for_user?(user)).to eq(false) }
    end

    context 'when the token does not refer to the current user' do
      it 'returns false' do
        other_user = create(:user, phone_confirmed_at: 90.days.ago)

        expect(subject.valid_for_user?(other_user)).to eq(false)
      end
    end

    context 'when the user has changed their phone since creating the token' do
      let(:created_at) { 5.days.ago }
      let(:phone_confirmed_at) { 4.days.ago }

      it { expect(subject.valid_for_user?(user)).to eq(false) }
    end
  end
end

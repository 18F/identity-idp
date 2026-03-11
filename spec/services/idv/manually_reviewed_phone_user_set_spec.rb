require 'rails_helper'

RSpec.describe Idv::ManuallyReviewedPhoneUserSet do
  let(:user_uuid) { SecureRandom.uuid }
  let(:manually_reviewed_phone_user_set) { described_class.new }
  let(:key) { described_class::KEY }

  before do
    REDIS_POOL.with do |client|
      client.del(key) # empty set before each test
    end
  end

  describe '#add_user!' do
    it 'adds a user to the set' do
      expect(manually_reviewed_phone_user_set.count).to eq 0
      manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
      manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
      expect(manually_reviewed_phone_user_set.count).to eq 1
      manually_reviewed_phone_user_set.add_user!(user_uuid: SecureRandom.uuid)
      expect(manually_reviewed_phone_user_set.count).to eq 2
    end
  end

  describe '#remove_user!' do
    it 'removes a user from the set' do
      expect(manually_reviewed_phone_user_set.count).to eq 0
      manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
      manually_reviewed_phone_user_set.add_user!(user_uuid: SecureRandom.uuid)
      expect(manually_reviewed_phone_user_set.count).to eq 2

      manually_reviewed_phone_user_set.remove_user!(user_uuid: user_uuid)
      expect(manually_reviewed_phone_user_set.count).to eq 1
    end
  end

  describe '#active_member?' do
    context 'when the user is not an active member' do
      it 'returns false' do
        manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
        expect(manually_reviewed_phone_user_set.member?(user_uuid: user_uuid)).to eq true
        expect(manually_reviewed_phone_user_set.active_member?(user_uuid: user_uuid)).to eq false
      end
    end

    context 'when the user is an active member' do
      before do
        allow(IdentityConfig.store).to receive(:idv_phone_confirmation_manual_review_validity_hours)
          .and_return(1)
      end

      it 'returns true' do
        manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
        expect(manually_reviewed_phone_user_set.member?(user_uuid: user_uuid)).to eq true
        expect(manually_reviewed_phone_user_set.active_member?(user_uuid: user_uuid)).to eq true
      end
    end
  end

  describe '#fetch_member_score' do
    it 'returns nil for non-members' do
      expect(manually_reviewed_phone_user_set.fetch_member_score(user_uuid: user_uuid)).to be_nil
    end

    it 'returns a numeric score for members' do
      manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
      expect(manually_reviewed_phone_user_set.fetch_member_score(user_uuid: user_uuid))
        .to be_within(5.seconds.to_i).of(Time.zone.now.to_i)
    end

    it 'returns the correct score for members' do
      manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
      orig_score = manually_reviewed_phone_user_set.fetch_member_score(user_uuid: user_uuid)
      expect(orig_score).to be_a_kind_of(Numeric)
      expect(orig_score).to be_within(15.seconds.to_i).of(Time.zone.now.to_i)

      travel_to(Time.zone.now + 1.day) do
        manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
      end
      new_score = manually_reviewed_phone_user_set.fetch_member_score(user_uuid: user_uuid)
      expect(new_score).to be_a_kind_of(Numeric)
      expect(new_score).to be > orig_score
      expect(new_score - orig_score).to be_within(5.seconds.to_i).of(1.day.to_i)
    end
  end
end

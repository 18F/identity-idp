require 'rails_helper'

RSpec.describe InPersonEnrollment, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to :user }
    it { is_expected.to belong_to :profile }
  end

  describe 'Status' do
    it 'defines enum correctly' do
      should define_enum_for(:status).
        with_values([:pending, :passed, :failed, :expired, :canceled])
    end
  end

  describe 'Constraints' do
    it 'requires the profile to be associated with the user' do
      user1 = create(:user)
      user2 = create(:user)
      profile2 = create(:profile, :verification_pending, user: user2)
      expect { create(:in_person_enrollment, user: user1, profile: profile2) }.
        to raise_error ActiveRecord::RecordInvalid
      expect(InPersonEnrollment.count).to eq 0
    end

    it 'does not allow more than one pending enrollment per user' do
      user = create(:user)
      profile = create(:profile, :verification_pending, user: user)
      profile2 = create(:profile, :verification_pending, user: user)
      create(:in_person_enrollment, user: user, profile: profile)
      expect(InPersonEnrollment.pending.count).to eq 1
      expect { create(:in_person_enrollment, user: user, profile: profile2) }.
        to raise_error ActiveRecord::RecordNotUnique
      expect(InPersonEnrollment.pending.count).to eq 1
    end

    it 'does not constrain enrollments for non-pending status' do
      user = create(:user)
      expect {
        InPersonEnrollment.statuses.each do |key,|
          status = InPersonEnrollment.statuses[key]
          profile = create(:profile, :verification_pending, user: user)
          create(:in_person_enrollment, user: user, profile: profile, status: status)
        end
        InPersonEnrollment.statuses.each do |key,|
          status = InPersonEnrollment.statuses[key]
          if status != InPersonEnrollment.statuses[:pending]
            profile = create(:profile, :verification_pending, user: user)
            create(:in_person_enrollment, user: user, profile: profile, status: status)
          end
        end
      }.not_to raise_error
      expect(InPersonEnrollment.pending.count).to eq 1
      expect(InPersonEnrollment.count).to eq(InPersonEnrollment.statuses.length * 2 - 1)
    end
  end
end

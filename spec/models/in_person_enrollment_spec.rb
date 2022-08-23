require 'rails_helper'

RSpec.describe InPersonEnrollment, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to :user }
    it { is_expected.to belong_to :profile }
  end

  describe 'Status' do
    it 'defines enum correctly' do
      should define_enum_for(:status).
        with_values([:establishing, :pending, :passed, :failed, :expired, :cancelled])
    end
  end

  describe 'Constraints' do
    it 'requires the profile to be associated with the user' do
      user1 = create(:user)
      user2 = create(:user)
      profile2 = create(:profile, :gpo_verification_pending, user: user2)
      expect { create(:in_person_enrollment, user: user1, profile: profile2) }.
        to raise_error ActiveRecord::RecordInvalid
      expect(InPersonEnrollment.count).to eq 0
    end

    it 'does not allow more than one pending enrollment per user' do
      user = create(:user)
      profile = create(:profile, :gpo_verification_pending, user: user)
      profile2 = create(:profile, :gpo_verification_pending, user: user)
      create(:in_person_enrollment, user: user, profile: profile, status: :pending)
      expect(InPersonEnrollment.pending.count).to eq 1
      expect { create(:in_person_enrollment, user: user, profile: profile2, status: :pending) }.
        to raise_error ActiveRecord::RecordNotUnique
      expect(InPersonEnrollment.pending.count).to eq 1
    end

    it 'does not allow duplicate unique ids' do
      user = create(:user)
      profile = create(:profile, :gpo_verification_pending, user: user)
      unique_id = InPersonEnrollment.generate_unique_id
      create(:in_person_enrollment, user: user, profile: profile, unique_id: unique_id)
      expect { create(:in_person_enrollment, user: user, profile: profile, unique_id: unique_id) }.
        to raise_error ActiveRecord::RecordNotUnique
      expect(InPersonEnrollment.count).to eq 1
    end

    it 'does not constrain enrollments for non-pending status' do
      user = create(:user)
      expect {
        InPersonEnrollment.statuses.each do |key,|
          status = InPersonEnrollment.statuses[key]
          profile = create(:profile, :gpo_verification_pending, user: user)
          create(:in_person_enrollment, user: user, profile: profile, status: status)
        end
        InPersonEnrollment.statuses.each do |key,|
          status = InPersonEnrollment.statuses[key]
          if status != InPersonEnrollment.statuses[:pending]
            profile = create(:profile, :gpo_verification_pending, user: user)
            create(:in_person_enrollment, user: user, profile: profile, status: status)
          end
        end
      }.not_to raise_error
      expect(InPersonEnrollment.pending.count).to eq 1
      expect(InPersonEnrollment.count).to eq(InPersonEnrollment.statuses.length * 2 - 1)
      expect(InPersonEnrollment.pending.first.status_updated_at).to_not be_nil
    end
  end

  describe 'needs_usps_status_check' do
    let(:check_interval) { ...1.hour.ago }
    let!(:passed_enrollment) { create(:in_person_enrollment, :passed) }
    let!(:failing_enrollment) { create(:in_person_enrollment, :failed) }
    let!(:expired_enrollment) { create(:in_person_enrollment, :expired) }
    let!(:checked_pending_enrollment) {
      create(:in_person_enrollment, :pending, status_check_attempted_at: Time.zone.now)
    }
    let!(:needy_enrollments) do
      [
        create(:in_person_enrollment, :pending),
        create(:in_person_enrollment, :pending),
        create(:in_person_enrollment, :pending),
        create(:in_person_enrollment, :pending),
      ]
    end

    it 'returns only pending enrollments' do
      expect(InPersonEnrollment.count).to eq(8)
      results = InPersonEnrollment.needs_usps_status_check(check_interval)
      expect(results.length).to eq needy_enrollments.length
      expect(results.pluck(:id)).to match_array needy_enrollments.pluck(:id)
      results.each do |result|
        expect(result.pending?).to be_truthy
      end
    end

    it 'indicates whether an enrollment needs a status check' do
      expect(passed_enrollment.needs_usps_status_check?(check_interval)).to be_falsey
      expect(failing_enrollment.needs_usps_status_check?(check_interval)).to be_falsey
      expect(expired_enrollment.needs_usps_status_check?(check_interval)).to be_falsey
      expect(checked_pending_enrollment.needs_usps_status_check?(check_interval)).to be_falsey
      needy_enrollments.each do |enrollment|
        expect(enrollment.needs_usps_status_check?(check_interval)).to be_truthy
      end
    end
  end

  describe 'complete?' do
    let(:cancelled_enrollment) { create(:in_person_enrollment, :cancelled) }
    let(:expired_enrollment) { create(:in_person_enrollment, :expired) }
    let(:failed_enrollment) { create(:in_person_enrollment, :failed) }
    let(:passed_enrollment) { create(:in_person_enrollment, :passed) }

    let(:establishing_enrollment) { create(:in_person_enrollment, :establishing) }
    let(:pending_enrollment) { create(:in_person_enrollment, :pending) }

    it 'returns true for completed enrollments' do
      expect(cancelled_enrollment.complete?).to eq(true)
      expect(expired_enrollment.complete?).to eq(true)
      expect(failed_enrollment.complete?).to eq(true)
      expect(passed_enrollment.complete?).to eq(true)
    end

    it 'returns false for incomplete enrollments' do
      expect(establishing_enrollment.complete?).to eq(false)
      expect(pending_enrollment.complete?).to eq(false)
    end
  end

  describe 'minutes_to_completion' do
    let(:enrollment) {
      enrollment = create(
        :in_person_enrollment, :passed, enrollment_established_at: Time.zone.now - 2.days
      )
      enrollment.status_updated_at = Time.zone.now - 1.hour
      enrollment
    }

    it 'returns number of minutes it took to reach completion' do
      expect(enrollment.minutes_to_completion).to be_within(0.01).of(2820)
    end

    it 'returns nil if enrollment is not completed' do
      enrollment.status = 'pending'

      expect(enrollment.minutes_to_completion).to eq(nil)
    end

    it 'returns nil if expected fields are not present' do
      enrollment.status_updated_at = nil

      expect(enrollment.minutes_to_completion).to eq(nil)

      enrollment.status_updated_at = Time.zone.now
      enrollment.enrollment_established_at = nil

      expect(enrollment.minutes_to_completion).to eq(nil)
    end
  end

  describe 'minutes_since_last_status_check' do
    let(:enrollment) {
      create(
        :in_person_enrollment, :passed, status_check_attempted_at: Time.zone.now - 2.hours
      )
    }

    it 'returns number of minutes since last status check' do
      expect(enrollment.minutes_since_last_status_check).to be_within(0.01).of(120)
    end

    it 'returns nil if enrollment has not been status-checked' do
      enrollment.status_check_attempted_at = nil

      expect(enrollment.minutes_since_last_status_check).to eq(nil)
    end
  end

  describe 'minutes_since_status_updated' do
    let(:enrollment) {
      enrollment = create(:in_person_enrollment, :passed)
      enrollment.status_updated_at = (Time.zone.now - 2.hours)
      enrollment
    }

    it 'returns number of minutes since the status was updated' do
      expect(enrollment.minutes_since_last_status_update).to be_within(0.01).of(120)
    end

    it 'returns nil if enrollment status has not been updated' do
      enrollment.status_updated_at = nil

      expect(enrollment.minutes_since_last_status_update).to eq(nil)
    end
  end
end

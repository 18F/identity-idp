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
      expect do
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
      end.not_to raise_error
      expect(InPersonEnrollment.pending.count).to eq 1
      expect(InPersonEnrollment.count).to eq(InPersonEnrollment.statuses.length * 2 - 1)
      expect(InPersonEnrollment.pending.first.status_updated_at).to_not be_nil
    end
  end

  describe 'Triggers' do
    it 'generates a unique ID if one is not provided' do
      user = create(:user)
      profile = create(:profile, :gpo_verification_pending, user: user)
      expect(InPersonEnrollment).to receive(:generate_unique_id).and_call_original

      enrollment = create(:in_person_enrollment, user: user, profile: profile)

      expect(enrollment.unique_id).not_to be_nil
    end

    it 'does not generated a unique ID if one is provided' do
      user = create(:user)
      profile = create(:profile, :gpo_verification_pending, user: user)
      expect(InPersonEnrollment).not_to receive(:generate_unique_id)

      enrollment = create(:in_person_enrollment, user: user, profile: profile, unique_id: '1234')

      expect(enrollment.unique_id).to eq('1234')
    end
  end

  describe 'needs_email_reminder' do
    let(:days) { IdentityConfig.store.email_reminder_early_benchmark }
    let!(:passed_enrollment) { create(:in_person_enrollment, :passed) }
    let!(:failing_enrollment) { create(:in_person_enrollment, :failed) }
    let!(:expired_enrollment) { create(:in_person_enrollment, :expired) }
    let!(:pending_enrollment_needing_reminder) do
      [
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 19.days),
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 26.days),
      ]
    end

    let!(:pending_enrollments) do
      [
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now),
        create(:in_person_enrollment, :pending, created_at: Time.zone.now),
      ]
    end

    it 'returns pending enrollments that need reminder' do
      expect(InPersonEnrollment.count).to eq(7)
      results = InPersonEnrollment.needs_email_reminder(days)
      expect(results.length).to eq pending_enrollment_needing_reminder.length
      expect(results.pluck(:id)).to match_array pending_enrollment_needing_reminder.pluck(:id)
      results.each do |result|
        expect(result.pending?).to be_truthy
      end
    end

    it 'excludes pending enrollments that do not need reminder' do
      results = InPersonEnrollment.needs_email_reminder(days)
      expect(results.pluck(:id)).not_to match_array pending_enrollments.pluck(:id)
    end
  end

  describe 'needs_usps_status_check' do
    let(:check_interval) { ...1.hour.ago }
    let!(:passed_enrollment) { create(:in_person_enrollment, :passed) }
    let!(:failing_enrollment) { create(:in_person_enrollment, :failed) }
    let!(:expired_enrollment) { create(:in_person_enrollment, :expired) }
    let!(:checked_pending_enrollment) do
      create(:in_person_enrollment, :pending, status_check_attempted_at: Time.zone.now)
    end
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

  describe 'minutes_since_established' do
    let(:enrollment) do
      create(
        :in_person_enrollment, :passed, enrollment_established_at: Time.zone.now - 2.hours
      )
    end

    it 'returns number of minutes since enrollment was established' do
      expect(enrollment.minutes_since_established).to be_within(0.01).of(120)
    end

    it 'returns nil if enrollment has not been established' do
      enrollment.status = 'establishing'
      enrollment.enrollment_established_at = nil

      expect(enrollment.minutes_since_established).to eq(nil)
    end
  end

  describe 'minutes_since_last_status_check' do
    let(:enrollment) do
      create(
        :in_person_enrollment, :passed, status_check_attempted_at: Time.zone.now - 2.hours
      )
    end

    it 'returns number of minutes since last status check' do
      expect(enrollment.minutes_since_last_status_check).to be_within(0.01).of(120)
    end

    it 'returns nil if enrollment has not been status-checked' do
      enrollment.status_check_attempted_at = nil

      expect(enrollment.minutes_since_last_status_check).to eq(nil)
    end
  end

  describe 'minutes_since_status_updated' do
    let(:enrollment) do
      enrollment = create(:in_person_enrollment, :passed)
      enrollment.status_updated_at = (Time.zone.now - 2.hours)
      enrollment
    end

    it 'returns number of minutes since the status was updated' do
      expect(enrollment.minutes_since_last_status_update).to be_within(0.01).of(120)
    end

    it 'returns nil if enrollment status has not been updated' do
      enrollment.status_updated_at = nil

      expect(enrollment.minutes_since_last_status_update).to eq(nil)
    end
  end
end

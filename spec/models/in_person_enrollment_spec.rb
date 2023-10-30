require 'rails_helper'

RSpec.describe InPersonEnrollment, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to :user }
    it { is_expected.to belong_to :profile }
    it { is_expected.to belong_to :service_provider }
    it { is_expected.to have_one(:notification_phone_configuration).dependent(:destroy) }
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
      profile2 = create(:profile, gpo_verification_pending_at: 1.day.ago, user: user2)
      expect { create(:in_person_enrollment, user: user1, profile: profile2) }.
        to raise_error ActiveRecord::RecordInvalid
      expect(InPersonEnrollment.count).to eq 0
    end

    it 'does not allow more than one pending enrollment per user' do
      user = create(:user)
      profile = create(:profile, gpo_verification_pending_at: 1.day.ago, user: user)
      profile2 = create(:profile, gpo_verification_pending_at: 1.day.ago, user: user)
      create(:in_person_enrollment, user: user, profile: profile, status: :pending)
      expect(InPersonEnrollment.pending.count).to eq 1
      expect { create(:in_person_enrollment, user: user, profile: profile2, status: :pending) }.
        to raise_error ActiveRecord::RecordNotUnique
      expect(InPersonEnrollment.pending.count).to eq 1
    end

    it 'does not allow duplicate unique ids' do
      user = create(:user)
      profile = create(:profile, gpo_verification_pending_at: 1.day.ago, user: user)
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
          profile = create(:profile, gpo_verification_pending_at: 1.day.ago, user: user)
          create(:in_person_enrollment, user: user, profile: profile, status: status)
        end
        InPersonEnrollment.statuses.each do |key,|
          status = InPersonEnrollment.statuses[key]
          if status != InPersonEnrollment.statuses[:pending]
            profile = create(:profile, gpo_verification_pending_at: 1.day.ago, user: user)
            create(:in_person_enrollment, user: user, profile: profile, status: status)
          end
        end
      end.not_to raise_error
      expect(InPersonEnrollment.pending.count).to eq 1
      expect(InPersonEnrollment.count).to eq(InPersonEnrollment.statuses.length * 2 - 1)
      expect(InPersonEnrollment.pending.first.status_updated_at).to_not be_nil
    end
  end

  describe 'Callbacks' do
    describe 'when status is updated' do
      it 'sets status_updated_at' do
        enrollment = create(:in_person_enrollment, :establishing)
        freeze_time do
          current_time = Time.zone.now
          expect(enrollment.status_updated_at).to be_nil
          enrollment.update(status: InPersonEnrollment::STATUS_CANCELLED)
          expect(enrollment.status_updated_at).to eq(current_time)
        end
      end

      describe 'enrollment expires or is canceled' do
        it 'deletes the notification phone number' do
          statuses = [InPersonEnrollment::STATUS_CANCELLED, InPersonEnrollment::STATUS_EXPIRED]
          statuses.each do |status|
            enrollment = create(
              :in_person_enrollment, :pending, :with_notification_phone_configuration
            )
            config_id = enrollment.notification_phone_configuration.id
            expect(NotificationPhoneConfiguration.find_by({ id: config_id })).to_not be_nil

            enrollment.update(status: status)
            enrollment.reload

            expect(enrollment.notification_phone_configuration).to be_nil
            expect(NotificationPhoneConfiguration.find_by({ id: config_id })).to be_nil
          end
        end
      end
    end

    describe 'when notification_sent_at is updated' do
      context 'enrollment has a notification phone configuration' do
        let!(:enrollment) do
          create(:in_person_enrollment, :passed, :with_notification_phone_configuration)
        end

        it 'destroys the notification phone configuration' do
          expect(enrollment.notification_phone_configuration).to_not be_nil

          enrollment.update(notification_sent_at: Time.zone.now)

          expect(enrollment.reload.notification_phone_configuration).to be_nil
        end
      end

      context 'enrollment does not have a notification phone configuration' do
        let!(:enrollment) { create(:in_person_enrollment, :passed) }

        it 'does not raise an error' do
          expect(enrollment.notification_phone_configuration).to be_nil
          expect { enrollment.update!(notification_sent_at: Time.zone.now) }.to_not raise_error
        end
      end
    end

    it 'generates a unique ID if one is not provided' do
      user = create(:user)
      profile = create(:profile, gpo_verification_pending_at: 1.day.ago, user: user)
      expect(InPersonEnrollment).to receive(:generate_unique_id).and_call_original

      enrollment = create(:in_person_enrollment, user: user, profile: profile)

      expect(enrollment.unique_id).not_to be_nil
    end

    it 'does not generated a unique ID if one is provided' do
      user = create(:user)
      profile = create(:profile, gpo_verification_pending_at: 1.day.ago, user: user)
      expect(InPersonEnrollment).not_to receive(:generate_unique_id)

      enrollment = create(:in_person_enrollment, user: user, profile: profile, unique_id: '1234')

      expect(enrollment.unique_id).to eq('1234')
    end
  end

  describe 'enrollments that need email reminders' do
    let(:early_benchmark) { Time.zone.now - 19.days }
    let(:late_benchmark) { Time.zone.now - 26.days }
    let(:final_benchmark) { Time.zone.now - 29.days }

    # early reminder is sent on days 11-5
    let!(:enrollments_needing_early_reminder) do
      [
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 19.days),
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 25.days),
      ]
    end

    # late reminder is sent on days 4 - 2
    let!(:enrollments_needing_late_reminder) do
      [
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 26.days),
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 28.days),
      ]
    end

    let!(:enrollments_needing_no_reminder) do
      [
        create(:in_person_enrollment, :passed),
        create(:in_person_enrollment, :failed),
        create(:in_person_enrollment, :expired),
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now),
        create(:in_person_enrollment, :pending, created_at: Time.zone.now),
      ]
    end

    it 'returns pending enrollments that need early reminder' do
      expect(InPersonEnrollment.count).to eq(9)
      results = InPersonEnrollment.needs_early_email_reminder(early_benchmark, late_benchmark)
      expect(results.pluck(:id)).to match_array enrollments_needing_early_reminder.pluck(:id)
      results.each do |result|
        expect(result.pending?).to be_truthy
        expect(result.early_reminder_sent?).to be_falsey
      end
    end

    it 'returns pending enrollments that need late reminder' do
      expect(InPersonEnrollment.count).to eq(9)
      results = InPersonEnrollment.needs_late_email_reminder(late_benchmark, final_benchmark)
      expect(results.pluck(:id)).to match_array enrollments_needing_late_reminder.pluck(:id)
      results.each do |result|
        expect(result.pending?).to be_truthy
        expect(result.late_reminder_sent?).to be_falsey
      end
    end
  end

  describe 'enrollments that need a status check' do
    let(:check_interval) { ...1.hour.ago }
    let!(:passed_enrollment) { create(:in_person_enrollment, :passed) }
    let!(:failed_enrollment) { create(:in_person_enrollment, :failed) }
    let!(:expired_enrollment) { create(:in_person_enrollment, :expired) }
    let!(:checked_pending_enrollment) do
      create(:in_person_enrollment, :pending, last_batch_claimed_at: Time.zone.now)
    end
    let!(:needy_enrollments) { create_list(:in_person_enrollment, 4, :pending) }

    it 'needs_usps_status_check returns only needy enrollments' do
      expect(InPersonEnrollment.count).to eq(8)
      results = InPersonEnrollment.needs_usps_status_check(check_interval)
      expect(results.pluck(:id)).to match_array needy_enrollments.pluck(:id)
      results.each { |result| expect(result.pending?).to eq(true) }
    end

    it 'needs_usps_status_check_batch returns only matching enrollments' do
      freeze_time do
        batch_at = Time.zone.now
        needy_enrollments.first(2).each do |enrollment|
          enrollment.update(last_batch_claimed_at: batch_at)
        end
        results = InPersonEnrollment.needs_usps_status_check_batch(batch_at)
        expect(results.pluck(:id)).to match_array needy_enrollments.first(2).pluck(:id)
      end
    end

    it 'indicates whether an enrollment needs a status check' do
      expect(passed_enrollment.needs_usps_status_check?(check_interval)).to eq(false)
      expect(failed_enrollment.needs_usps_status_check?(check_interval)).to eq(false)
      expect(expired_enrollment.needs_usps_status_check?(check_interval)).to eq(false)
      expect(checked_pending_enrollment.needs_usps_status_check?(check_interval)).to eq(false)
      needy_enrollments.each do |enrollment|
        expect(enrollment.needs_usps_status_check?(check_interval)).to eq(true)
      end
    end
  end

  describe 'status checks for ready and waiting enrollments' do
    let(:check_interval) { ...1.hour.ago }
    let!(:passed_enrollment) do
      create(:in_person_enrollment, :passed, ready_for_status_check: true)
    end
    let!(:failed_enrollment) do
      create(:in_person_enrollment, :failed, ready_for_status_check: true)
    end
    let!(:expired_enrollment) do
      create(:in_person_enrollment, :expired, ready_for_status_check: true)
    end
    let!(:checked_pending_enrollment) do
      create(
        :in_person_enrollment,
        :pending,
        last_batch_claimed_at: Time.zone.now,
        ready_for_status_check: true,
      )
    end
    let!(:ready_enrollments) do
      create_list(:in_person_enrollment, 4, :pending, ready_for_status_check: true)
    end
    let!(:needy_enrollments) do
      create_list(:in_person_enrollment, 4, :pending, ready_for_status_check: false)
    end

    it 'needs_status_check_on_ready_enrollments returns only ready pending enrollments' do
      expect(InPersonEnrollment.count).to eq(12)
      ready_results = InPersonEnrollment.needs_status_check_on_ready_enrollments(check_interval)
      expect(ready_results.pluck(:id)).to match_array ready_enrollments.pluck(:id)
      expect(ready_results.pluck(:id)).not_to match_array needy_enrollments.pluck(:id)
      ready_results.each { |result| expect(result.pending?).to eq(true) }
    end

    it 'needs_status_check_on_ready_enrollment? tells whether an enrollment needs a status check' do
      other_enrollments = [
        passed_enrollment,
        failed_enrollment,
        expired_enrollment,
        checked_pending_enrollment,
      ]

      (other_enrollments + needy_enrollments).each do |enrollment|
        expect(enrollment.needs_status_check_on_ready_enrollment?(check_interval)).to eq(false)
      end

      ready_enrollments.each do |enrollment|
        expect(enrollment.needs_status_check_on_ready_enrollment?(check_interval)).to eq(true)
      end
    end

    it 'needs_status_check_on_waiting_enrollments returns only not ready pending enrollments' do
      expect(InPersonEnrollment.count).to eq(12)
      waiting_results = InPersonEnrollment.needs_status_check_on_waiting_enrollments(check_interval)
      expect(waiting_results.pluck(:id)).to match_array needy_enrollments.pluck(:id)
      expect(waiting_results.pluck(:id)).not_to match_array ready_enrollments.pluck(:id)
      waiting_results.each { |result| expect(result.pending?).to eq(true) }
    end

    it 'indicates whether a waiting enrollment needs a status check' do
      other_enrollments = [
        passed_enrollment,
        failed_enrollment,
        expired_enrollment,
        checked_pending_enrollment,
      ]

      (other_enrollments + ready_enrollments).each do |enrollment|
        expect(enrollment.needs_status_check_on_waiting_enrollment?(check_interval)).to eq(false)
      end

      needy_enrollments.each do |enrollment|
        expect(enrollment.needs_status_check_on_waiting_enrollment?(check_interval)).to eq(true)
      end
    end
  end

  describe 'minutes_since_established' do
    it 'returns number of minutes since enrollment was established' do
      freeze_time do
        enrollment = create(
          :in_person_enrollment,
          :passed,
          enrollment_established_at: Time.zone.now - 2.hours,
        )
        expect(enrollment.minutes_since_established).to eq 120
      end
    end

    it 'returns nil if enrollment has not been established' do
      enrollment = create(:in_person_enrollment, :establishing, enrollment_established_at: nil)

      expect(enrollment.minutes_since_established).to be_nil
    end
  end

  describe 'minutes_since_last_status_check' do
    it 'returns number of minutes since last status check' do
      freeze_time do
        enrollment = create(
          :in_person_enrollment,
          status_check_attempted_at: Time.zone.now - 2.hours,
        )
        expect(enrollment.minutes_since_last_status_check).to eq 120
      end
    end

    it 'returns nil if enrollment has not been status-checked' do
      enrollment = create(:in_person_enrollment, status_check_attempted_at: nil)

      expect(enrollment.minutes_since_last_status_check).to be_nil
    end
  end

  describe 'minutes_since_last_status_check_completed' do
    it 'returns number of minutes since last status check was completed' do
      freeze_time do
        enrollment = create(
          :in_person_enrollment,
          status_check_completed_at: Time.zone.now - 2.hours,
        )
        expect(enrollment.minutes_since_last_status_check_completed).to eq 120
      end
    end

    it 'returns nil if enrollment has not completed a status check' do
      enrollment = create(:in_person_enrollment, status_check_completed_at: nil)

      expect(enrollment.minutes_since_last_status_check_completed).to be_nil
    end
  end

  describe 'minutes_since_last_status_update' do
    it 'returns number of minutes since the status was updated' do
      freeze_time do
        enrollment = create(:in_person_enrollment, status_updated_at: Time.zone.now - 2.hours)
        expect(enrollment.minutes_since_last_status_update).to eq 120
      end
    end

    it 'returns nil if enrollment status has not been updated' do
      enrollment = create(:in_person_enrollment, status_updated_at: nil)

      expect(enrollment.minutes_since_last_status_update).to be_nil
    end
  end

  describe 'due_date and days_to_due_date' do
    let(:validity_in_days) { 10 }
    let(:days_ago_established_at) { 7 }
    let(:today) { Time.zone.now }
    let(:nine_days_ago) { today - 9.days }
    let(:nine_and_a_half_days_ago) { today - 9.5.days }
    let(:ten_days_ago) { today - 10.days }

    before do
      allow(IdentityConfig.store).
        to(
          receive(:in_person_enrollment_validity_in_days).
          and_return(validity_in_days),
        )
    end

    it 'due_date returns the enrollment expiration date based on when it was established' do
      freeze_time do
        enrollment = create(
          :in_person_enrollment,
          enrollment_established_at: days_ago_established_at.days.ago,
        )
        expect(enrollment.due_date).to(
          eq((validity_in_days - days_ago_established_at).days.from_now),
        )
      end
    end

    it 'days_to_due_date returns the number of days left until the due date' do
      freeze_time do
        enrollment = create(
          :in_person_enrollment,
          enrollment_established_at: days_ago_established_at.days.ago,
        )
        expect(enrollment.days_to_due_date).to eq(validity_in_days - days_ago_established_at)
      end
    end

    context 'check edges to confirm date calculation is correct' do
      it 'returns the correct due date and days to due date with 1 day left' do
        freeze_time do
          enrollment = create(
            :in_person_enrollment,
            enrollment_established_at: nine_days_ago,
          )
          expect(enrollment.days_to_due_date).to eq(1)
          expect(enrollment.due_date).to eq(today + 1.day)
        end
      end

      it 'returns the correct due date and days to due date with 0.5 days left' do
        freeze_time do
          enrollment = create(
            :in_person_enrollment,
            enrollment_established_at: nine_and_a_half_days_ago,
          )
          expect(enrollment.days_to_due_date).to eq(0)
          expect(enrollment.due_date).to eq(today + 0.5.days)
        end
      end

      it 'returns the correct due date and days to due date with 0 days left' do
        freeze_time do
          enrollment = create(
            :in_person_enrollment,
            enrollment_established_at: ten_days_ago,
          )
          expect(enrollment.days_to_due_date).to eq(0)
          expect(enrollment.due_date).to eq(today)
        end
      end
    end
  end

  describe 'eligible_for_notification?' do
    let(:passed_enrollment) do
      create(:in_person_enrollment, :passed, :with_notification_phone_configuration)
    end
    let(:failed_enrollment) do
      create(:in_person_enrollment, :failed, :with_notification_phone_configuration)
    end
    let(:expired_enrollment) do
      create(:in_person_enrollment, :expired, :with_notification_phone_configuration)
    end
    let(:incomplete_enrollment) do
      create(:in_person_enrollment, :with_notification_phone_configuration)
    end
    let(:passed_enrollment_without_notification) do
      create(:in_person_enrollment, :passed)
    end
    let(:failed_enrollment_without_notification) do
      create(:in_person_enrollment, :failed)
    end

    it 'returns true when status of passed/failed/expired and with notification configuration' do
      expect(passed_enrollment.eligible_for_notification?).to eq(true)
      expect(failed_enrollment.eligible_for_notification?).to eq(true)
    end

    it 'returns false when status of incomplete, expired, or without notification configuration' do
      expect(incomplete_enrollment.eligible_for_notification?).to eq(false)
      expect(expired_enrollment.eligible_for_notification?).to eq(false)
      expect(passed_enrollment_without_notification.eligible_for_notification?).to eq(false)
      expect(failed_enrollment_without_notification.eligible_for_notification?).to eq(false)
    end
  end
end

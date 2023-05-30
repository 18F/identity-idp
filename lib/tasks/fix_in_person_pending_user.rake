namespace :profiles do
  desc 'If a profile is pending in-person and pending GPO remove the GPO pending status'
  task fix_in_person_and_gpo_pending_user: :environment do
    enrollments = InPersonEnrollment.pending.joins(:profile).where(
      'profiles.gpo_verification_pending_at IS NOT NULL',
    )
    enrollments.each do |enrollment|
      enrollment.profile.update!(gpo_verification_pending_at: nil)
    end
  end
end

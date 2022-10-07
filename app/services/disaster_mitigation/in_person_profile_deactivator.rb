module DisasterMitigation
  class InPersonProfileDeactivator
    def self.deactivate_pending_profiles(issuer, dry_run)
      started_at = Time.zone.now
      # todo: catch, log, and handle exceptions
      # todo: log to somehwere that gets sent to cloudwatch

      validate_arguments(issuer, dry_run)

      profiles = pending_profiles(issuer)
      puts "Found #{profiles.count} profiles to deactivate"

      deactivate_profiles(profiles) unless dry_run

      finished_at = Time.zone.now
      profiles_updated = dry_run ? 0 : profiles.count
      {
        dry_run: dry_run,
        duration_seconds: finished_at - started_at,
        finished_at: finished_at,
        issuer: issuer,
        profiles_count: profiles.count,
        profiles_updated: profiles_updated,
        started_at: started_at,
        target_profiles: 'pending and deactivated profiles',
      }
    end

    def reactivate_pending_profiles(issuer, dry_run)
      started_at = Time.zone.now
      # todo: catch, log, and handle exceptions
      # todo: log to somehwere that gets sent to cloudwatch

      validate_arguments(issuer, dry_run)

      profiles = pending_and_deactivated_profiles(issuer)
      puts "Found #{profiles.count} profiles to deactivate"

      reactivate_profiles(profiles) unless dry_run

      finished_at = Time.zone.now
      profiles_updated = dry_run ? 0 : profiles.count
      {
        dry_run: dry_run,
        duration_seconds: finished_at - started_at,
        finished_at: finished_at,
        issuer: issuer,
        profiles_count: profiles.count,
        profiles_updated: profiles_updated,
        started_at: started_at,
        target_profiles: 'pending and deactivated profiles',
      }
    end

    def deactivate_passed_profiles(issuer, dry_run); end

    def reactivate_passed_profiles(issuer, dry_run); end

    def deactivate_pending_or_passed_profiles(issuer, dry_run); end

    def reactivate_pending_or_passed_profiles(issuer, dry_run); end

    private

    def self.validate_arguments(issuer, dry_run)
      # todo: ensure issuer is a string or nil and dry_run is a boolean
    end

    def self.deactivate_profiles(profiles)
      # todo: consider running all of this in one transaction
      profiles.each do |profile|
        profile.deactivate('in_person_verification_deactivated')
        profile.in_person_enrollment.status = 'cancelled'
        profile.in_person_enrollment.save!
      end
    end

    def self.reactivate_profiles(profiles)
      # todo: either do all profiles in other transaction or each profile in one transaction
      # todo: what should happen if the user has created a new profile since they were deactivated?
      profiles.each do |profile|
        profile.activate
        profile.in_person_enrollment.status = 'pending'
        profile.in_person_enrollment.save!
      end
    end

    def self.pending_profiles(issuer)
      Profile.where("proofing_components->>'document_check'= 'usps'").where(
        active: false, deactivation_reason: 'in_person_verification_pending',
      ).joins(:in_person_enrollment).where(in_person_enrollment: { status: 'pending',
                                                                   issuer: issuer })
    end

    def self.passed_profiles(issuer)
    end

    def self.pending_or_passed_profiles(issuer)
    end

    def self.pending_and_deactivated_profiles(issuer)
    end

    def self.passed_and_deactivated_profiles(issuer)
    end

    def self.deactivated_profiles(issuer)
    end

    def self.queries
      # just some misc queries I wanted to keep around as WIP
      # all IPP profiles
      profiles = Profile.where("proofing_components->>'document_check' = 'usps'")
      # active IPP profiles
      # note: the join and check for passed is not necessary; we could just be satisfied if it is active. we could still perform the check for an enrollment as a data integrity check though. another data integrity check is making sure that the deactivation reason is nil
      active_profiles = Profile.where("proofing_components->>'document_check'= 'usps'").where(active: true)
      active_profiles.each do |profile|
        unless profile.deactivation_reason.nil? && profile&.in_person_enrollment&.status == 'passed'
          puts "deactivation_reason is nil? #{profile.deactivation_reason.nil?}; enrollments passed? #{profile&.in_person_enrollment&.status == 'passed'}"
          raise 'Unexpected state'
        end
      end
    end
  end
end

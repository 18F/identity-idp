module DisasterMitigation
  class InPersonProfileDeactivator
    def self.deactivate_profiles(dry_run, status_type, partner_id)
      # todo: catch errors, handle errors
      validate_arguments(status_type, partner_id)
      # expected params: partner ID, activate or deactivate, pending or active or both
      puts 'Deactivating some profiles!'
      puts 'Steps to reverse this process: tktk'

      profiles = retrieve_profiles(status_type, partner_id)

      puts "Found #{profiles.count} profiles to deactivate"

      profiles.each do |profile|
        continue if dry_run
        profile.deactivate('in_person_contingency_deactivation')
        profile.in_person_enrollment.status = 'cancelled'
        profile.in_person_enrollment.save!
      end

      puts 'Completed'
      puts 'Steps to reverse this process: tktk'
    end

    def self.validate_arguments(status_type, partner_id)
      # tktk
      # ensure status_type is a valid value
      # any checks for partner id?
    end

    def self.retrieve_profiles(status_type, partner_id)
      if status_type == 'pending'
        pending_profiles(partner_id)
      elsif status_type == 'passed'
        active_profiles(partner_id)
      else
        pending_and_active_profiles(partner_id)
      end
    end

    def self.pending_profiles(partner_id)
      # will this work with nil partner_id?
      Profile.where("proofing_components->>'document_check'= 'usps'").where(
        active: false, deactivation_reason: 'in_person_verification_pending',
      ).joins(:in_person_enrollment).where(in_person_enrollment: { status: 'pending',
                                                                   issuer: partner_id })
    end

    def self.active_profiles(partner_id)
    end

    def self.pending_and_active_profiles(partner_id)
    end

    def self.queries
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

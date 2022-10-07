module DisasterMitigation
  class InPersonProfileDeactivator
    def self.deactivate_profiles(status_type, partner_id, dry_run, reversal_info)
      validate_arguments(status_type, partner_id)
      # todo: catch, log, and handle exceptions
      # todo: log to somehwere that gets sent to cloudwatch
      puts 'Deactivating some profiles!'
      puts "Steps to reverse this process: #{reversal_info}"

      profiles = retrieve_profiles(status_type, partner_id)

      puts "Found #{profiles.count} profiles to deactivate"

      unless dry_run
        # todo: consider running all of this in one transaction
        profiles.each do |profile|
          profile.deactivate('in_person_verification_deactivated')
          profile.in_person_enrollment.status = 'cancelled'
          profile.in_person_enrollment.save!
        end
      end

      puts "Steps to reverse this process: #{reversal_info}"
      # todo: log some stats: count of target records found, count of records updated, duration of task
      puts 'Completed'
    end

    def self.validate_arguments(status_type, partner_id)
      # todo: ensure status_type is a valid value
      # todo: ensure partner_id is a string
    end

    def self.retrieve_profiles(status_type, partner_id)
      if status_type == 'pending'
        pending_profiles(partner_id)
      elsif status_type == 'passed'
        active_profiles(partner_id)
      elsif status_type == 'pending or passed'
        pending_or_passed_profiles(partner_id)
      elsif status_type == 'pending and deactivated'
        pending_and_deactivated_profiles(partner_id)
      elsif status_type == 'passed and deactivated'
        passed_and_deactivated_profiles(partner_id)
      elsif status_type == 'deactivated'
        deactivated_profiles(partner_id)
      end
    end

    def self.pending_profiles(partner_id)
      Profile.where("proofing_components->>'document_check'= 'usps'").where(
        active: false, deactivation_reason: 'in_person_verification_pending',
      ).joins(:in_person_enrollment).where(in_person_enrollment: { status: 'pending',
                                                                   issuer: partner_id })
    end

    def self.passed_profiles(partner_id)
    end

    def self.pending_or_passed_profiles(partner_id)
    end

    def self.pending_and_deactivated_profiles(partner_id)
    end

    def self.passed_and_deactivated_profiles(partner_id)
    end

    def self.deactivated_profiles(partner_id)
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

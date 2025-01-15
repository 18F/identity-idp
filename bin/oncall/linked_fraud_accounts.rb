#!/usr/bin/env ruby

require_relative '../../config/environment.rb'

class LinkedFraudAccounts
  def self.run(out: STDOUT, argv: ARGV)
    user_uuid = nil
    parser = OptionParser.new do |opts|
      opts.banner = <<~EOM
        Usage: #{$PROGRAM_NAME} --uuid=UUID
      EOM

      opts.on('--uuid=UUID', String, 'UUID to query for') do |uuid|
        user_uuid = uuid
      end
    end

    parser.parse!(argv)

    unless user_uuid
      puts "Error: No UUID specified"
      exit 1
    end

    user = User.find_by_uuid user_uuid #.join(:profiles)
    unless user
      puts "Error: No user found with uuid='#{user_uuid}'"
      exit 1
    end

    # A user might have multiple profiles, not all active.
    profiles = Profile.where(user_id: user.id).joins(:user)

    ssn_signatures = profiles.map(&:ssn_signature).uniq
    handprints = profiles.map(&:name_zip_birth_year_signature).uniq

    puts "--- User accounts matching SSN fingerprint ---"
    # Find all SSN signatures
    linked_ssn_profiles = Profile.where(ssn_signature: ssn_signatures).joins(:user)
    # In my console this seems to do one-off selects still?
    puts linked_ssn_profiles.map { |p| p.user.uuid }

    puts "\n--- User accounts matching name + ZIP + birthyear ---"
    linked_handprint_profiles = Profile.where(name_zip_birth_year_signature: handprints).joins(:user)
    puts linked_handprint_profiles.map { |p| p.user.uuid }
  enda
end

if $PROGRAM_NAME == __FILE__
  LinkedFraudAccounts.run
end

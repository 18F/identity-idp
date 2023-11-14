require './lib/cleanup/destroyable_records'
# Remove unused issuers
#
# When the IdP gets deployed, it generates a list of issuers that need to be removed and emails them
# to us. These emails are available in Zendesk - check the "Suspended Tickets" bucket for the most
# recent ticket titled:
# "[production] identity-idp error: ServiceProviderSeeder::ExtraServiceProviderError".
#
# This script iterates over a list of those issuers, outputs the data that is to be deleted, and
# then requires user confirmation before deleting the issuer and associated models.
#
#
# As of 11/2/2023: The rake task isn't working, to remove unused providers log into a box in the
# environment you want to remove unused providers from. Enter into a rails console and enter the
# following commands:
# > require 'cleanup/destroy_unused_providers'
# > issuers=['list','of','issuers','to','remove']
# > dup = DestroyUnusedProviders.new(issuers)
# > dup.run

class DestroyUnusedProviders
  attr_reader :destroy_list, :stdin, :stdout

  def initialize(unused_issuers, stdin: STDIN, stdout: STDOUT)
    @stdin = stdin
    @stdout = stdout
    @destroy_list = unused_issuers.map { |issuer| DestroyableRecords.new(issuer, stdin:, stdout:) }
  end

  def run
    @destroy_list.each do |records|
      if records.service_provider.blank?
        stdout.puts "Issuer #{records.issuer} is not associated with a service provider."
        stdout.puts 'Please check if it has already been deleted'
        break
      end

      records.print_data

      break if records.service_provider.in_person_enrollments.size > 0

      stdout.puts "Type 'yes' and hit enter to continue and " \
                    "destroy this service provider and associated records:\n"

      continue = stdin.gets.chomp

      if continue != 'yes'
        stdout.puts 'You have indicated there is an issue. Aborting script'
        break
      end

      records.destroy_records
    end
    nil
  end
end

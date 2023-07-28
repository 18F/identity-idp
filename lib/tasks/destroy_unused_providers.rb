#!/usr/bin/env ruby

# Remove unused issuers
#
# When the IdP gets deployed, it generates a list of issuers that need to be removed and emails them to us.
# These emails are available in Zendesk - check the "Suspended Tickets" bucket for the most recent ticket titled
# "[production] identity-idp error: ServiceProviderSeeder::ExtraServiceProviderError".
#
# This script iterates over a list of those issuers, outputs the data that is to be deleted, and then
# requires user confirmation before deleting the issuer and associated models.

class DestroyUnusedProviders
  attr_reader :destroy_list
  def initialize(unused_issuers)
    @destroy_list = unused_issuers.map {|issuer| DestroyableRecords.new(issuer)}
  end

  def run
    @destroy_list.each do |records|
      records.print_data

      puts "Type 'yes' and hit enter to continue and destroy this service provider and associated records:\n"
      continue = gets.chomp

      if continue != "yes"
        puts "You have indicated there is an issue. Aborting script"
        break
      end

      records.destroy_records
    end
  end

  class DestroyableRecords
    attr_reader :sp, :int

    def initialize(issuer)
      @sp = ServiceProvider.includes(:in_person_enrollments).find_by_issuer(issuer)
      @int = Agreements::Integration.includes(:partner_account, iaa_orders: [:iaa_gtc]).find_by_issuer(issuer)
    end

    def integration_usages
      int.integration_usages
    end

    def iaa_orders
      int.iaa_orders
    end

    def in_person_enrollments
      sp.in_person_enrollments
    end

    def iaa_gtc

    end

    def print_data
      puts "You are about to delete a service provider with issuer #{sp.issuer}"
      puts "The partner is #{int.partner_account.name}"
      puts "\n\n"

      puts "Attributes:"
      puts sp.attributes
      puts "\n"

      puts "********"
      puts "Integration:"
      puts int.attributes
      puts "\n"

      puts "********"
      puts "This provider has #{in_person_enrollments.size} in person enrollments that will be destroyed"
      puts "\n"

      puts "*******"
      puts "These are the IAA orders that will be affected: \n"
      iaa_orders.each do |iaa_order|
        puts "#{iaa_order.iaa_gtc.gtc_number} #{iaa_order.order_number}"
      end
      puts "\n"
    end

    def destroy_records
      puts "Destroying integration usages"
      integration_usages.each do |iu|
        iu.destroy!
      end
      int.reload

      puts "Destroying integration with issuer #{int.issuer}"
      int.destroy!
      sp.reload

      puts "Destroying service provider issuer #{sp.issuer}"
      sp.destroy!
    end
  end
end



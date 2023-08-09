#!/usr/bin/env ruby

# Remove unused issuers
#
# When the IdP gets deployed, it generates a list of issuers that need to be removed and emails them
# to us. These emails are available in Zendesk - check the "Suspended Tickets" bucket for the most
# recent ticket titled:
# "[production] identity-idp error: ServiceProviderSeeder::ExtraServiceProviderError".
#
# This script iterates over a list of those issuers, outputs the data that is to be deleted, and
# then requires user confirmation before deleting the issuer and associated models.

class DestroyUnusedProviders
  attr_reader :destroy_list
  def initialize(unused_issuers)
    @destroy_list = unused_issuers.map { |issuer| DestroyableRecords.new(issuer) }
  end

  def run
    @destroy_list.each do |records|
      records.print_data

      Rails.logger.debug do
        "Type 'yes' and hit enter to continue and " \
                         "destroy this service provider and associated records:\n"
      end
      continue = gets.chomp

      if continue != 'yes'
        Rails.logger.debug 'You have indicated there is an issue. Aborting script'
        break
      end

      records.destroy_records
    end
    nil
  end

  class DestroyableRecords
    attr_reader :sp, :int, :issuer

    def initialize(issuer)
      @issuer = issuer
      @sp = ServiceProvider.includes(:in_person_enrollments).find_by(issuer: issuer)
      @int = Agreements::Integration.includes(
        :partner_account,
        iaa_orders: [:iaa_gtc],
      ).find_by(issuer: issuer)
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
      Rails.logger.debug { "You are about to delete a service provider with issuer #{sp.issuer}" }
      Rails.logger.debug { "The partner is #{int.partner_account.name}" }
      Rails.logger.debug "\n\n"

      Rails.logger.debug 'Attributes:'
      Rails.logger.debug sp.attributes
      Rails.logger.debug "\n"

      Rails.logger.debug '********'
      Rails.logger.debug 'Integration:'
      Rails.logger.debug int.attributes
      Rails.logger.debug "\n"

      Rails.logger.debug '********'
      Rails.logger.debug do
        "This provider has #{in_person_enrollments.size} in person enrollments " \
                         "that will be destroyed"
      end
      Rails.logger.debug "\n"

      Rails.logger.debug '*******'
      Rails.logger.debug "These are the IAA orders that will be affected: \n"
      iaa_orders.each do |iaa_order|
        Rails.logger.debug "#{iaa_order.iaa_gtc.gtc_number} #{iaa_order.order_number}"
      end
      Rails.logger.debug "\n"
    end

    def destroy_records
      Rails.logger.debug 'Destroying integration usages'
      integration_usages.each do |iu|
        iu.destroy!
      end
      int.reload

      Rails.logger.debug { "Destroying integration with issuer #{int.issuer}" }
      int.destroy!
      sp.reload

      Rails.logger.debug { "Destroying service provider issuer #{sp.issuer}" }
      sp.destroy!

      Rails.logger.debug do
        "ServiceProvider with issuer #{issuer} and associated records has been destroyed."
      end
    end
  end
end

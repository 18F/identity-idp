# frozen_string_literal: true

module Agreements
  class IaaOrderSeeder < BaseSeeder
    # The core functionality of this class is defined in BaseSeeder

    private

    def record_class
      IaaOrder
    end

    def filename
      'iaa_orders.yml'
    end

    def primary_attribute_bundle(config)
      { 'iaa_gtc_id' => config['iaa_gtc'].id, 'order_number' => config['order_number'] }
    end

    def process_config(_key, config)
      config['iaa_gtc'] = IaaGtc.find_by!(gtc_number: config['iaa_gtc'])

      # this is used in the after_seed method to generate the associated
      # IntegrationUsages after the IaaOrders are created / updated.
      @associated_integrations ||= {}
      key = [config['iaa_gtc'].id, config['order_number']]
      @associated_integrations[key] = config['integrations']

      permitted_attrs =
        %w[order_number mod_number start_date end_date estimated_amount iaa_gtc]
      config.slice(*permitted_attrs)
    end

    def after_seed
      return if @associated_integrations.blank?

      @associated_integrations.each do |(iaa_gtc_id, order_number), integrations|
        next if integrations.blank?

        order = IaaOrder.find_by!(iaa_gtc_id: iaa_gtc_id, order_number: order_number)

        integrations.each do |issuer|
          integration = Integration.find_by!(issuer: issuer)
          IntegrationUsage.find_or_create_by!(iaa_order: order, integration: integration)
        rescue ActiveRecord::RecordNotFound => e
          gtc = order.iaa_gtc.gtc_number
          message =
            "#{e.message} - #{filename}: #{gtc}-#{order.order_number} #{issuer}"
          raise ActiveRecord::RecordNotFound.new(message)
        end
      end
    end
  end
end

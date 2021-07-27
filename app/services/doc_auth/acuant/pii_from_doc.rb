require 'active_support/core_ext/time/zones'

module IdentityDocAuth
  module Acuant
    class PiiFromDoc
      VALUE = {
        'First Name' => :first_name,
        'Middle Name' => :middle_name,
        'Surname' => :last_name,
        'Address Line 1' => :address1,
        'Address City' => :city,
        'Address State' => :state,
        'Address Postal Code' => :zipcode,
        'Birth Date' => :dob,
        'Document Number' => :state_id_number,
        'Issuing State Code' => :state_id_jurisdiction,
        'Expiration Date' => :state_id_expiration,
      }.freeze

      def initialize(id_data_fields)
        @name_to_value = {}
        id_data_fields['Fields'].each do |field|
          @name_to_value[field['Name']] = field['Value']
        end
      end

      def call
        VALUE.each do |key, value|
          hash[value] = @name_to_value[key]
        end
        hash[:state_id_type] = 'drivers_license'
        hash[:dob] = convert_date(hash[:dob])
        hash[:state_id_expiration] = convert_date(hash[:state_id_expiration])
        hash
      end

      ACUANT_TIMESTAMP_FORMAT = %r{/Date\((?<milliseconds>-?\d+)\)/}.freeze

      # @api private
      def convert_date(date)
        match = ACUANT_TIMESTAMP_FORMAT.match(date)
        return if !match || !match[:milliseconds]

        Time.zone.at(match[:milliseconds].to_f / 1000).utc.to_date.to_s
      end

      private

      def hash
        @hash ||= {}
      end
    end
  end
end

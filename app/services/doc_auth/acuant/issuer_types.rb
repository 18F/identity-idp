module DocAuth
  module Acuant
    module IssuerTypes
      IssuerType = Struct.new(:code, :name)

      UNKNOWN = IssuerType.new(0, 'Unknown').freeze
      COUNTRY = IssuerType.new(1, 'Country').freeze
      STATE_OR_PROVINCE = IssuerType.new(2, 'StateProvince').freeze
      TRIBAL = IssuerType.new(3, 'Tribal').freeze
      MUNICIPALITY = IssuerType.new(4, 'Municipality').freeze
      BUSINESS = IssuerType.new(5, 'Business').freeze
      OTHER = IssuerType.new(6, 'Other').freeze

      ALL = [
        UNKNOWN,
        COUNTRY,
        STATE_OR_PROVINCE,
        TRIBAL,
        MUNICIPALITY,
        BUSINESS,
        OTHER,
      ].freeze

      BY_CODE = ALL.index_by(&:code).freeze
      def self.from_int(code)
        BY_CODE[code]
      end
    end
  end
end

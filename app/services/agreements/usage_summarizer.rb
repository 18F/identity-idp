module Agreements
  class UsageSummarizer
    def self.call(**args)
      new(**args).call
    end

    def initialize(iaas:)
      @iaas = iaas
      @iaas_by_issuer = map_iaas_to_issuers
      @usage = {
        iaas: empty_iaa_usage_hash,
      }
    end

    def call
      Db::SpReturnLogScan.call do |return_log|
        @usage[:iaas].transform_values! { |iaa_usage| iaa_usage.count(return_log) }
      end

      usage
    end

    private

    attr_reader :iaas, :iaas_by_issuer, :usage

    def map_iaas_to_issuers
      iaas.each_with_object(Hash.new([])) do |iaa, hash|
        issuers = iaa.order.integrations.map(&:issuer)
        issuers.each { |issuer| hash[issuer] << iaa }
      end
    end

    def empty_iaa_usage_hash
      iaas.each_with_object({}) do |iaa, hash|
        hash[iaa.iaa_number] = IaaUsage.new(order: iaa.order)
      end
    end
  end
end

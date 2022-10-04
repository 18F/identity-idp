module Proofing
  module LexisNexis
    module InstantVerify
      class CheckToAttributeMapper
        InstantVerifyCheck = Struct.new(:name, :status, keyword_init: true)

        attr_reader :instant_verify_checks

        CHECK_NAME_TO_ATTRIBUTE_MAP = {
          'Addr1Zip_StateMatch' => :address,
          'SsnFullNameMatch' => :ssn,
          'SsnDeathMatchVerification' => :dead,
          'SSNSSAValid' => :ssn,
          'IdentityOccupancyVerified' => :address,
          'AddrDeliverable' => :address,
          'AddrNotHighRisk' => :address,
          'DOBFullVerified' => :dob,
          'DOBYearVerified' => :dob,
          'LexIDDeathMatch' => :dead,
        }.freeze

        def initialize(instant_verify_errors)
          items = instant_verify_errors&.dig('Items')
          if items.present?
            @instant_verify_checks = instant_verify_errors['Items'].map do |item|
              InstantVerifyCheck.new(name: item['ItemName'], status: item['ItemStatus'])
            end
          else
            @instant_verify_checks = []
          end
        end

        def map_failed_checks_to_attributes
          instant_verify_checks.map do |instant_verify_check|
            next if instant_verify_check.status == 'pass'
            CHECK_NAME_TO_ATTRIBUTE_MAP[instant_verify_check.name] || :unknown
          end.compact.uniq.sort
        end
      end
    end
  end
end

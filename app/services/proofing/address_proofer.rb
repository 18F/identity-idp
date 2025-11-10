# frozen_string_literal: true

module Proofing
  class AddressProofer
    class InvalidAddressVendorError < StandardError; end

    attr_reader :user_uuid, :user_email

    ADDRESS_VENDOR_SP_COST_TOKENS = {
      mock: :mock_address,
      lexis_nexis: :lexis_nexis_address,
      socure: :socure_address,
    }.freeze

    def initialize(user_uuid:, user_email:)
      @user_uuid = user_uuid
      @user_email = user_email
    end

    def proof(
      applicant_pii:,
      current_sp:
    )
      results = []
      address_vendors.each do |address_vendor|
        result = proofer(address_vendor).proof(applicant_pii)
          .tap do |res|
            Db::SpCost::AddSpCost.call(
              current_sp, sp_cost_token(address_vendor), transaction_id: res.transaction_id
            )
          end
        results << result
        break if result.success?
      end
      results
    end

    private

    def sp_cost_token(address_vendor)
      ADDRESS_VENDOR_SP_COST_TOKENS[address_vendor].tap do |token|
        if !token.present?
          raise InvalidAddressVendorError,
                "No cost token present for address vendor #{address_vendor}"
        end
      end
    end

    def proofer(address_vendor)
      case address_vendor
      when :lexis_nexis
        Proofing::LexisNexis::PhoneFinder::Proofer.new(
          phone_finder_workflow: IdentityConfig.store.lexisnexis_phone_finder_workflow,
          account_id: IdentityConfig.store.lexisnexis_account_id,
          base_url: IdentityConfig.store.lexisnexis_base_url,
          username: IdentityConfig.store.lexisnexis_username,
          password: IdentityConfig.store.lexisnexis_password,
          hmac_key_id: IdentityConfig.store.lexisnexis_hmac_key_id,
          hmac_secret_key: IdentityConfig.store.lexisnexis_hmac_secret_key,
          request_mode: IdentityConfig.store.lexisnexis_request_mode,
        )
      when :socure
        Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer.new(
          Proofing::Socure::IdPlus::Config.new(
            user_uuid:,
            user_email:,
            api_key: IdentityConfig.store.socure_idplus_api_key,
            base_url: IdentityConfig.store.socure_idplus_base_url,
            timeout: IdentityConfig.store.socure_idplus_timeout_in_seconds,
          ),
        )
      when :mock
        Proofing::Mock::AddressMockClient.new
      else
        raise InvalidAddressVendorError, "#{address_vendor} is not a valid address vendor"
      end
    end

    def primary_vendor
      IdentityConfig.store.idv_address_primary_vendor
    end

    def secondary_vendor
      IdentityConfig.store.idv_address_secondary_vendor
    end

    def address_vendors
      [primary_vendor, secondary_vendor].uniq.compact
    end
  end
end

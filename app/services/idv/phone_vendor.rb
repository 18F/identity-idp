# frozen_string_literal: true

module Idv::PhoneVendor
  def self.address_verification_vendor(vendor)
    return if vendor.blank?

    case vendor
    when 'socure_phonerisk'
      'socure_address'
    when 'lexis_nexis_address', 'AddressMock'
      'lexis_nexis_address'
    else
      vendor
    end
  end
end

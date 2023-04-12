class OutageStatus
  include ActionView::Helpers::TranslationHelper

  IDV_VENDORS = %i[acuant lexisnexis_instant_verify lexisnexis_trueid].freeze
  PHONE_VENDORS = %i[sms voice].freeze
  ALL_VENDORS = (IDV_VENDORS + PHONE_VENDORS).freeze

  def vendor_outage?(vendor)
    status = case vendor
    when :acuant
      IdentityConfig.store.vendor_status_acuant
    when :lexisnexis_instant_verify
      IdentityConfig.store.vendor_status_lexisnexis_instant_verify
    when :lexisnexis_trueid
      IdentityConfig.store.vendor_status_lexisnexis_trueid
    when :lexisnexis_phone_finder
      IdentityConfig.store.vendor_status_lexisnexis_phone_finder
    when :sms
      IdentityConfig.store.vendor_status_sms
    when :voice
      IdentityConfig.store.vendor_status_voice
    else
      raise ArgumentError, "invalid vendor #{vendor}"
    end
    status != :operational
  end

  def any_vendor_outage?(vendors = ALL_VENDORS)
    vendors.any? { |vendor| vendor_outage?(vendor) }
  end

  def all_vendor_outage?(vendors = ALL_VENDORS)
    vendors.all? { |vendor| vendor_outage?(vendor) }
  end

  def any_idv_vendor_outage?
    any_vendor_outage?(IDV_VENDORS)
  end

  def any_phone_vendor_outage?
    any_vendor_outage?(PHONE_VENDORS)
  end

  def all_phone_vendor_outage?
    all_vendor_outage?(PHONE_VENDORS)
  end

  def phone_finder_outage?
    all_vendor_outage?([:lexisnexis_phone_finder])
  end

  # Returns an appropriate error message based upon the type of outage or what the user was doing
  # when they encountered the outage.
  #
  # @return [String, nil] the localized message.
  def outage_message
    if any_idv_vendor_outage?
      t('vendor_outage.blocked.idv.generic')
    elsif any_phone_vendor_outage?
      t('vendor_outage.blocked.phone.default')
    end
  end

  def track_event(analytics)
    raise ArgumentError, 'analytics instance required' if analytics.nil?

    analytics.vendor_outage(
      vendor_status: {
        acuant: IdentityConfig.store.vendor_status_acuant,
        lexisnexis_instant_verify: IdentityConfig.store.vendor_status_lexisnexis_instant_verify,
        lexisnexis_trueid: IdentityConfig.store.vendor_status_lexisnexis_trueid,
        sms: IdentityConfig.store.vendor_status_sms,
        voice: IdentityConfig.store.vendor_status_voice,
      },
    )
  end
end

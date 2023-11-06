class OutageStatus
  include ActionView::Helpers::TranslationHelper

  IDV_VENDORS = %i[
    acuant
    lexisnexis_instant_verify
    lexisnexis_trueid
    idv_scheduled_maintenance
  ].freeze
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
    when :idv_scheduled_maintenance
      idv_scheduled_maintenance_status
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

  def idv_scheduled_maintenance_status
    if idv_scheduled_maintenance?
      :full_outage
    else
      :operational
    end
  end

  # @return [Boolean] returns true when we are currently within a scheduled maintenance window
  def idv_scheduled_maintenance?(now: Time.zone.now)
    start = IdentityConfig.store.vendor_status_idv_scheduled_maintenance_start
    finish = IdentityConfig.store.vendor_status_idv_scheduled_maintenance_finish

    if start.present? && finish.present?
      (start.in_time_zone('UTC')...finish.in_time_zone('UTC')).cover?(now)
    end
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
        idv_scheduled_maintenance: idv_scheduled_maintenance_status,
      },
    )
  end
end

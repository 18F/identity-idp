class VendorStatus
  def initialize(from: nil, from_idv: nil, sp: nil)
    @from = from
    @from_idv = from_idv
    @sp = sp
  end

  IAL2_VENDORS = %i[acuant lexisnexis_instant_verify lexisnexis_trueid].freeze
  ALL_VENDORS = (IAL2_VENDORS + %i[sms voice]).freeze

  def vendor_outage?(vendor)
    status = case vendor
    when :acuant
      IdentityConfig.store.vendor_status_acuant
    when :lexisnexis_instant_verify
      IdentityConfig.store.vendor_status_lexisnexis_instant_verify
    when :lexisnexis_trueid
      IdentityConfig.store.vendor_status_lexisnexis_trueid
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

  def any_ial2_vendor_outage?
    any_vendor_outage?(IAL2_VENDORS)
  end

  def from_idv?
    from_idv
  end

  # Returns an appropriate error message based upon the type of outage or what the user was doing
  # when they encountered the outage.
  #
  # @return [String, nil] the localized message.
  def outage_message
    if any_ial2_vendor_outage?
      if from_idv?
        if sp
          return I18n.t(
            'vendor_outage.idv_blocked.with_sp',
            service_provider: sp.friendly_name,
          )
        else
          return I18n.t('vendor_outage.idv_blocked.without_sp')
        end
      end

      return I18n.t('vendor_outage.idv_blocked.generic')
    end
  end

  def track_event(analytics)
    raise ArgumentError, 'analytics instance required' if analytics.nil?

    tracking_data = {
      vendor_status: {
        acuant: IdentityConfig.store.vendor_status_acuant,
        lexisnexis_instant_verify: IdentityConfig.store.vendor_status_lexisnexis_instant_verify,
        lexisnexis_trueid: IdentityConfig.store.vendor_status_lexisnexis_trueid,
      },
      redirect_from: from,
    }
    analytics.track_event(Analytics::VENDOR_OUTAGE, tracking_data)
  end

  private

  attr_reader :from, :from_idv, :sp
end

class VendorStatus
  include ActionView::Helpers::TranslationHelper

  def initialize(from: nil, from_idv: nil, sp: nil)
    @from = from
    @from_idv = from_idv
    @sp = sp
  end

  IAL2_VENDORS = %i[acuant lexisnexis_instant_verify lexisnexis_trueid].freeze
  PHONE_VENDORS = %i[sms voice].freeze
  ALL_VENDORS = (IAL2_VENDORS + PHONE_VENDORS).freeze

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

  def all_vendor_outage?(vendors = ALL_VENDORS)
    vendors.all? { |vendor| vendor_outage?(vendor) }
  end

  def any_ial2_vendor_outage?
    any_vendor_outage?(IAL2_VENDORS)
  end

  def any_phone_vendor_outage?
    any_vendor_outage?(PHONE_VENDORS)
  end

  def all_phone_vendor_outage?
    all_vendor_outage?(PHONE_VENDORS)
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
          t('vendor_outage.blocked.idv.with_sp', service_provider: sp.friendly_name)
        else
          t('vendor_outage.blocked.idv.without_sp')
        end
      else
        t('vendor_outage.blocked.idv.generic')
      end
    elsif any_phone_vendor_outage?
      if from_idv?
        t('vendor_outage.blocked.phone.idv')
      else
        t('vendor_outage.blocked.phone.default')
      end
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
      redirect_from: from,
    )
  end

  private

  attr_reader :from, :from_idv, :sp
end

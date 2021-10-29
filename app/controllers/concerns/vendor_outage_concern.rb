module VendorOutageConcern
  extend ActiveSupport::Concern

  ALL_VENDORS = %i[acuant lexisnexis_instant_verify lexisnexis_trueid voice sms]
  IAL2_VENDORS = %i[acuant lexisnexis_instant_verify lexisnexis_trueid]

  def redirect_if_outage(vendors:, from: nil)
    if any_vendor_outage?(vendors)
      session[:vendor_outage_redirect] = from
      return redirect_to vendor_outage_url
    end
  end

  def any_vendor_outage?(vendors = ALL_VENDORS)
    vendors.any? { |vendor| vendor_outage?(vendor) }
  end

  def vendor_outage?(vendor)
    raise ArgumentError, "invalid vendor #{vendor}" if !ALL_VENDORS.include?(vendor)

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
               raise ArgumentError, "invalid vendor #{vendor}" if !ALL_VENDORS.include?(vendor)
             end
    status != :operational
  end

  def any_ial2_vendor_outage?
    any_vendor_outage?(IAL2_VENDORS)
  end

  def from_create_account?
    session[:vendor_outage_redirect] == SignUp::RegistrationsController::CREATE_ACCOUNT
  end

  def from_idv?
    /IdV: /.match?(session[:vendor_outage_redirect])
  end

  def outage_message
    if any_ial2_vendor_outage?
      if from_idv?
        if current_sp
          return t(
            'vendor_outage.idv_blocked.unfortunately.with_sp',
            service_provider: current_sp.friendly_name,
          )
        else
          return t('vendor_outage.idv_blocked.unfortunately.without_sp')
        end
      end

      return t('vendor_outage.idv_blocked.generic') # if from_create_account?
    end
  end
end

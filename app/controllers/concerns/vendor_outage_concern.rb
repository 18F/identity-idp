module VendorOutageConcern
  extend ActiveSupport::Concern

  def redirect_if_outage(from: nil)
    if full_outage?
      session[:vendor_outage_redirect] = from
      return redirect_to vendor_outage_url
    end
  end

  def full_outage?
    acuant_outage? || instant_verify_outage? || trueid_outage?
  end

  def acuant_outage?
    IdentityConfig.store.vendor_status_acuant == 'full_outage'
  end

  def instant_verify_outage?
    IdentityConfig.store.vendor_status_lexisnexis_instant_verify == 'full_outage'
  end

  def trueid_outage?
    IdentityConfig.store.vendor_status_lexisnexis_trueid == 'full_outage'
  end

  def lexisnexis_outage?
    instant_verify_outage? || trueid_outage?
  end

  def outage_message
    t('vendor_outage.doc_auth.full') if full_outage?
  end
end

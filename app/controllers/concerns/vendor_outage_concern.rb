module VendorOutageConcern
  extend ActiveSupport::Concern

  # included do
  #   before_action :redirect_if_outage
  # end

  def redirect_if_outage(from: nil)
    if full_outage?
      session[:vendor_outage_redirect] = from
      redirect_to vendor_outage_url
    end
  end

  def full_outage?
    acuant_outage? || instant_verify_outage? || trueid_outage?
  end

  def acuant_outage?
    IdentityConfig.store.outage_acuant == 'full'
  end

  def instant_verify_outage?
    IdentityConfig.store.outage_lexisnexis_instant_verify == 'full'
  end

  def trueid_outage?
    IdentityConfig.store.outage_lexisnexis_trueid == 'full'
  end

  def lexisnexis_outage?
    instant_verify_outage? || trueid_outage?
  end

  def outage_message
    t('vendor_outage.doc_auth.full') if full_outage?
  end
end

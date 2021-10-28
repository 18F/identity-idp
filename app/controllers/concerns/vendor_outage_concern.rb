module VendorOutageConcern
  extend ActiveSupport::Concern

  def redirect_if_outage(from: nil)
    if full_ial2_outage?
      session[:vendor_outage_redirect] = from
      return redirect_to vendor_outage_url
    end
  end

  def full_ial2_outage?
    acuant_outage? || instant_verify_outage? || trueid_outage?
  end

  def acuant_outage?
    IdentityConfig.store.vendor_status_acuant == :full_outage
  end

  def instant_verify_outage?
    IdentityConfig.store.vendor_status_lexisnexis_instant_verify == :full_outage
  end

  def trueid_outage?
    IdentityConfig.store.vendor_status_lexisnexis_trueid == :full_outage
  end

  def lexisnexis_outage?
    instant_verify_outage? || trueid_outage?
  end

  def from_create_account?
    session[:vendor_outage_redirect] == SignUp::RegistrationsController::CREATE_ACCOUNT
  end

  def from_idv?
    /IdV: /.match?(session[:vendor_outage_redirect])
  end

  def outage_message
    if full_ial2_outage?
      return t('vendor_outage.idv_blocked.generic') if from_create_account?

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
    end
  end
end

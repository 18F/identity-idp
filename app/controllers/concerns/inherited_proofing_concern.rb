# Methods to aid in handling incoming requests from 3rd-party
# inherited proofing service providers. Exclusively, methods
# to handle and help manage incoming requests to create a
# Login.gov account.
module InheritedProofingConcern
  extend ActiveSupport::Concern

  include Idv::InheritedProofing::ServiceProviders

  def inherited_proofing_service_provider
    return VA if va_inherited_proofing?
  end

  # Department of Veterans Affairs (VA) methods.
  # https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/identity/Inherited%20Proofing/MHV%20Inherited%20Proofing/inherited-proofing-interface.md

  # Returns true if the incoming request has been identified as a
  # request to create a Login.gov account via inherited proofing
  # from the VA.
  def va_inherited_proofing?
    va_inherited_proofing_auth_code.present?
  end

  # The VA calls Login.gov to initiate inherited proofing of their
  # users. An authorization code is passed as a query param that needs to
  # be used in subsequent requests; this method returns this authorization
  # code.
  def va_inherited_proofing_auth_code
    @va_inherited_proofing_auth_code ||=
      decorated_session.request_url_params[va_inherited_proofing_auth_code_params_key]
  end

  def va_inherited_proofing_auth_code_params_key
    'inherited_proofing_auth'
  end

  def inherited_proofing_service_provider_data
    if inherited_proofing_service_provider == VA
      { auth_code: va_inherited_proofing_auth_code }
    else
      {}
    end
  end
end

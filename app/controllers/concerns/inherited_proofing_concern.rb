# Methods to aid in handling incoming requests from 3rd-party
# inherited proofing service providers. Exclusively, methods
# to handle and help manage incoming requests to create a
# Login.gov account.
module InheritedProofingConcern
  extend ActiveSupport::Concern

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

  # Service Provider-agnostic members

  def inherited_proofing_service_class
    if va_inherited_proofing?
      # TODO: Remove hard-coded false for final check in. This forces
      # the mock VA service to be called. Turning
      # IdentityConfig.store.inherited_proofing_enabled off doesn't help
      # us in dev, because we will get 404 errors when calling the
      # idv/inherited_proofing controller.
      return case false && IdentityConfig.store.inherited_proofing_enabled
             when true
               Idv::InheritedProofing::Va::Service
             else
               Idv::InheritedProofing::Va::Mocks::Service
             end
    end

    raise('Inherited proofing service class could not be identified')
  end

  def inherited_proofing_service
    service_class = inherited_proofing_service_class
    return service_class.new va_inherited_proofing_auth_code if va_inherited_proofing?

    raise('Inherited proofing service could not be identified')
  end

  def inherited_proofing_form(payload_hash)
    return Idv::InheritedProofing::Va::Form.new payload_hash: payload_hash if va_inherited_proofing?

    raise('Inherited proofing form could not be identified')
  end

  def inherited_proofing_service_provider_data
    if va_inherited_proofing?
      { va_inherited_proofing_auth_code: va_inherited_proofing_auth_code }
    else
      {}
    end
  end
end

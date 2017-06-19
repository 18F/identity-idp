class NullIdentity
  SERVICE_PROVIDER = 'null-identity-service-provider'.freeze

  def service_provider
    SERVICE_PROVIDER
  end

  def deactivate
    # no-op
  end

  def sp_metadata
    {}
  end

  def session_uuid
    nil
  end
end

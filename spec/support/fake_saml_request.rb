class FakeSamlRequest
  def service_provider
    self
  end

  def identifier
    'http://localhost:3000'
  end
end

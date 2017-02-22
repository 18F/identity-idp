class NullServiceProvider
  attr_accessor :issuer

  def initialize(issuer:)
    @issuer = issuer
  end

  def active?
    false
  end

  def native?
    false
  end

  def live?
    false
  end

  def metadata
    {}
  end

  def fingerprint
    nil
  end

  def ssl_cert
    nil
  end
end

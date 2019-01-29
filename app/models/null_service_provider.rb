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

  def fingerprint; end

  def ssl_cert; end

  def logo; end

  def friendly_name; end

  def failure_to_proof_url; end

  def return_to_sp_url; end

  def pkce; end

  def redirect_uris
    []
  end
end

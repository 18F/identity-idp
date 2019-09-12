class NullServiceProvider
  attr_accessor :issuer, :friendly_name
  attr_accessor :ial

  def initialize(issuer:, friendly_name: "Null ServiceProvider")
    @issuer = issuer
    @friendly_name = friendly_name
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

  def failure_to_proof_url; end

  def return_to_sp_url; end

  def pkce; end

  def redirect_uris
    []
  end
end

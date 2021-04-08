class NullServiceProvider
  attr_accessor :issuer, :friendly_name
  attr_accessor :ial

  COLUMNS = %i[
    aal
    acs_url
    active
    agency
    agency_id
    allow_prompt_login
    app_id
    approved
    assertion_consumer_logout_service_url
    attribute_bundle
    block_encryption
    cert
    certs
    created_at
    default_aal
    description
    failure_to_proof_url
    fingerprint
    help_text
    iaa
    iaa_end_date
    iaa_start_date
    ial2_quota
    id
    identities
    launch_date
    logo
    metadata_url
    native
    piv_cac
    piv_cac_scoped_by_email
    pkce
    push_notification_url
    remote_logo_key
    return_to_sp_url
    signature
    signed_response_message_requested
    sp_initiated_login_url
    ssl_cert
    updated_at
  ].freeze

  COLUMNS.each do |col|
    define_method(col) { nil }
  end

  def initialize(issuer:, friendly_name: 'Null ServiceProvider')
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

  def redirect_uris
    []
  end

  def identities
    []
  end

  def liveness_checking_required
    false
  end

  def encrypt_responses?
    false
  end

  def encryption_opts; end

  def skip_encryption_allowed
    false
  end

  def allow_prompt_login
    false
  end
end

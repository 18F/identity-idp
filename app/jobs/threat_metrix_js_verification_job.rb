class ThreatMetrixJsVerificationJob < ApplicationJob
  queue_as :default

  def perform(session_id: SecureRandom.uuid)
    org_id = IdentityConfig.store.lexisnexis_threatmetrix_org_id
    js = nil
    valid = nil
    error = nil
    signature = nil

    # Certificate is stored ASCII-armored in config
    raw_cert = IdentityConfig.store.lexisnexis_threatmetrix_js_signing_cert
    cert = OpenSSL::X509::Certificate.new(raw_cert) if raw_cert.present?
    raise 'JS signing certificate is missing' if !cert
    raise 'JS signing certificate is expired' if cert.not_after < Time.zone.now

    url = "https://h.online-metrix.net/fp/tags.js?org_id=#{org_id}&session_id=#{session_id}"
    resp = build_faraday.get(url)
    content, signature = parse_js(resp.body)

    valid = js_verified?(content, signature, cert)
    # When signature validation fails, we include the JS payload in the
    # log message for future analysis
    js = content if !valid
  rescue => err
    error = err
    raise err
  ensure
    logger.info(
      {
        name: 'ThreatMetrixJsVerification',
        org_id: org_id,
        session_id: session_id,
        http_status: resp&.status,
        signature: (signature || '').each_byte.map { |b| b.to_s(16).rjust(2, '0') }.join,
        js: js,
        valid: valid,
        error_class: error&.class,
        error_message: error&.message,
      }.compact.to_json,
    )
  end

  def build_faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.response :raise_error
    end
  end

  def parse_js(raw)
    # The signature is a hexadecimal string at the end of the JS, preceded by "//"
    sig_index = raw.rindex '//'
    return [raw] if sig_index.nil?

    signature = raw[sig_index + 2, raw.length]

    # Signatures must be hexadecimal numbers
    return [raw] if /[^a-fA-F0-9]/.match? signature

    # Convert hexadecimal signature back into binary data
    signature = [signature].pack('H*')

    content = raw[0, sig_index]

    [content, signature]
  end

  def js_verified?(js, signature, cert)
    return false if signature.nil?

    public_key = cert&.public_key
    return false if public_key.nil?

    public_key.verify('SHA256', signature, js)
  end
end

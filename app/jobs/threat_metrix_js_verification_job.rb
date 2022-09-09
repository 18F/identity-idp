class ThreatMetrixJsVerificationJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :default

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(session_id:)
    raise_stale_job! if stale_job?(enqueued_at)

    org_id = IdentityConfig.store.lexisnexis_threatmetrix_org_id
    session_id ||= SecureRandom.uuid

    return if !org_id

    return if !IdentityConfig.store.proofing_device_profiling_collecting_enabled

    # Certificate is stored ASCII-armored in config
    raw_cert = IdentityConfig.store.lexisnexis_threatmetrix_js_signing_cert
    return if !raw_cert

    cert = OpenSSL::X509::Certificate.new raw_cert

    url = "https://h.online-metrix.net/fp/tags.js?org_id=#{org_id}&session_id=#{session_id}"

    resp = build_faraday.get url

    content, signature = parse_js resp.body

    log_payload = {
      name: 'ThreatMetrixJsVerification',
      org_id: org_id,
      session_id: session_id,
      http_status: resp.status,
      signature: (signature || '').each_byte.map { |b| b.to_s(16).rjust(2, '0') }.join,
      certificate_expiry: cert.not_after,
    }

    if verify_js content, signature, cert
      log_payload[:valid] = true
    else
      # When signature validation fails, we include the JS payload in the
      # log message for future analysis
      log_payload[:valid] = false
      log_payload[:js] = content
    end

    logger.info(log_payload.to_json)
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
    signature = signature.
      strip.
      scan(/../).
      map { |x| x.hex.chr }.
      join

    content = raw[0, sig_index]

    [content, signature]
  end

  def verify_js(js, signature, cert)
    return false if signature.nil?

    public_key = cert&.public_key
    return false if public_key.nil?

    public_key.verify 'SHA256', signature, js
  end
end

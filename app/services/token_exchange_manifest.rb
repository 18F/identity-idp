# frozen_string_literal: true

# Resolves the set of target issuers a broker SP is allowed to exchange tokens
# for, by fetching the broker's own SIGNED service manifest rather than a
# hardcoded allowlist. The manifest is a capability-limiting allowlist the
# broker controls: it is the ONLY thing that can widen the set of targets an
# exchange may mint for, so a drifted or compromised broker client can be
# contained by editing the manifest at the source.
#
# The manifest is a compact JWS (RFC 7515) -- a signed JWT whose claims are
# `{ iss, aud, exp, nbf, iat, services: [...] }`, signed RS256. The protected
# header carries a `kid` so the broker can rotate signing keys.
#
# Trust rules (all must hold, else the target set is empty):
#   * signature verifies (RS256, against the configured key named by `kid`)
#   * `iss` matches the broker issuer we asked for
#   * `aud` matches our own issuer (manifest can't be replayed at another IdP)
#   * `exp`/`nbf` are valid (with small clock-skew leeway)
#
# Caching & containment: at login-scale we cannot fetch per request, so a
# verified result is cached. The cached copy is trusted for at most
# `min(exp, CACHE_TTL)` and we FAIL CLOSED afterwards -- if the broker is
# unreachable past that window we return [] rather than serving a stale (and
# possibly since-revoked) allowlist. Revocation therefore always takes effect
# within CACHE_TTL even if the manifest host is down.
module TokenExchangeManifest
  module_function

  SIGNING_ALGORITHM = 'RS256'
  # Longest we will reuse a verified manifest before refetching. Bounds
  # revocation latency and caps load on the broker at scale.
  CACHE_TTL = 15.minutes.freeze
  # Hard cap on how long a cache entry is physically retained (so its validators
  # survive past the trust window to enable conditional revalidation). Trust is
  # still bounded by trusted_until, never by retention.
  MAX_RETENTION = 24.hours.freeze
  # Clock-skew tolerance for exp/nbf validation (RFC 7519 §4.1.4/§4.1.5).
  LEEWAY = 60

  # @return [Array<String>] allowed target issuers for the broker (may be empty)
  def allowed_targets(broker_issuer)
    return [] if manifest_url(broker_issuer).blank?
    return [] unless secure_url?(manifest_url(broker_issuer))
    return [] if public_keys(broker_issuer).blank?

    cached = cached_entry(broker_issuer)
    return cached[:targets] if fresh?(cached)

    fetch_targets(broker_issuer, cached)
  rescue StandardError => err
    NewRelic::Agent.notice_error(err)
    # Fail closed: only reuse a cached copy that is still within its trust
    # window; never serve an expired (possibly revoked) allowlist.
    cached = cached_entry(broker_issuer)
    fresh?(cached) ? cached[:targets] : []
  end

  def manifest_url(broker_issuer)
    IdentityConfig.store.token_exchange_manifest_urls.to_h[broker_issuer]
  end

  # @return [Hash{String=>OpenSSL::PKey::RSA}] configured verification keys by kid
  def public_keys(broker_issuer)
    keys_by_kid = IdentityConfig.store.token_exchange_manifest_public_keys.to_h[broker_issuer]
    return {} if keys_by_kid.blank?

    keys_by_kid.each_with_object({}) do |(kid, pem), acc|
      acc[kid.to_s] = OpenSSL::PKey::RSA.new(pem)
    rescue OpenSSL::PKey::RSAError
      next
    end
  end

  # Require https to prevent manifest tampering, except for loopback hosts so
  # local development can serve over plain http.
  def secure_url?(url)
    uri = URI.parse(url)
    return true if uri.scheme == 'https'
    uri.scheme == 'http' && %w[localhost 127.0.0.1 ::1 [::1]].include?(uri.host)
  rescue URI::InvalidURIError
    false
  end

  # Conditional GET: replay stored validators. A 304 is only honored when the
  # cached manifest is still within its own signed `exp` -- otherwise the cached
  # copy has expired and must be re-verified, so we force a full fetch by
  # dropping the validators. This keeps `exp` enforced on the 304 path, not just
  # the 200 path.
  def fetch_targets(broker_issuer, cached)
    conditional = cached.present? && cached_within_exp?(cached)

    response = faraday.get(manifest_url(broker_issuer)) do |req|
      if conditional
        req.headers['If-None-Match'] = cached[:etag] if cached[:etag]
        req.headers['If-Modified-Since'] = cached[:last_modified] if cached[:last_modified]
      end
    end

    if response.status == 304
      # Only legitimately reachable when we sent validators, i.e. the cached
      # copy is still within exp; re-affirm it under a refreshed min(exp, TTL)
      # window. A 304 without a usable cache (misbehaving origin) fails closed.
      return [] unless conditional
      return store_and_return(broker_issuer, cached[:targets], cached[:expires_at], cached)
    end

    targets, expires_at = verify(response.body.to_s, broker_issuer)
    # Do not cache verification failures: a transient bad response must not
    # poison the allowlist for a full TTL. Fail closed for this request only.
    return [] if expires_at.blank?

    store_and_return(
      broker_issuer, targets, expires_at,
      { etag: response.headers['etag'], last_modified: response.headers['last-modified'] }
    )
  end

  def cached_within_exp?(cached)
    exp = cached[:expires_at]
    exp.present? && exp > Time.zone.now - LEEWAY
  end

  # Verifies the compact JWS. Returns [issuers, exp_time] or [[], nil] if the
  # signature, algorithm/kid, or any required claim (iss/aud/exp) is missing or
  # invalid. `exp` is REQUIRED: a manifest without it would otherwise get an
  # unbounded rolling trust window, dropping the min(exp, TTL) containment.
  def verify(jws, broker_issuer)
    keys = public_keys(broker_issuer)
    claims, = JWT.decode(
      jws.strip,
      nil,
      true,
      algorithm: SIGNING_ALGORITHM,
      iss: broker_issuer,
      verify_iss: true,
      aud: audience,
      verify_aud: true,
      verify_expiration: true,
      verify_not_before: true,
      required_claims: %w[iss aud exp],
      leeway: LEEWAY,
    ) { |header| keys[header['kid'].to_s] }

    targets = Array(claims['services']).filter_map do |service|
      service['issuer'].presence if service.is_a?(Hash)
    end
    exp = claims['exp'] ? Time.zone.at(claims['exp']) : nil
    [targets, exp]
  rescue JWT::DecodeError
    [[], nil]
  end

  # Our own issuer, asserted as the manifest audience so a manifest signed for
  # login cannot be replayed at a different relying party.
  def audience
    Rails.application.routes.url_helpers.root_url
  end

  def fresh?(entry)
    entry.present? && entry[:trusted_until].present? && entry[:trusted_until] > Time.zone.now
  end

  # Trust window is min(manifest exp, CACHE_TTL): the broker's exp can only
  # shorten how long we cache, never extend it past CACHE_TTL. Fails closed if
  # the resulting window is already in the past (e.g. an exp that lapsed).
  #
  # The entry is physically retained until the manifest's `exp` (capped at
  # MAX_RETENTION) -- longer than the trust window -- so the stored validators
  # survive past `trusted_until` and let us revalidate with a conditional GET
  # instead of a full re-download. Trust is still governed by `trusted_until`,
  # never by physical retention.
  def store_and_return(broker_issuer, targets, expires_at, meta)
    now = Time.zone.now
    trusted_until = [expires_at, now + CACHE_TTL].compact.min
    return [] if trusted_until <= now

    retention = [expires_at ? expires_at - now : CACHE_TTL, MAX_RETENTION].min
    store_entry(
      broker_issuer,
      {
        targets: targets,
        expires_at: expires_at,
        trusted_until: trusted_until,
        etag: meta[:etag],
        last_modified: meta[:last_modified],
      },
      retention,
    )
    targets
  end

  def cached_entry(broker_issuer)
    Rails.cache.read(cache_key(broker_issuer))
  end

  def store_entry(broker_issuer, entry, retention)
    Rails.cache.write(cache_key(broker_issuer), entry, expires_in: retention)
  end

  def cache_key(broker_issuer)
    "token_exchange_manifest:#{broker_issuer}"
  end

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.adapter :net_http
      conn.options.timeout = 5
      conn.response :raise_error
    end
  end
end

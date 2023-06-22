module ArcgisApi
  # Struct to store token information, this allows us to track
  # real expiration time with various rails cache backends many of them
  # do not support entry expiration.
  # Attributes
  #  token: the token string
  #  expires_at: hard expiration timestamp in epoch seconds
  #  sliding_expires_at: optional the token keeper to maintain for
  #   sliding expiration when sliding expiration enabled.
  #   A time that the token does not actually expire
  #   but used to control the timing of requesting a new token before it expires.
  #   It's initially set to expires_at - 3*prefetch_ttl.
  TokenInfo = Struct.new(
    :token,
    :expires_at,
    :sliding_expires_at,
  )
end
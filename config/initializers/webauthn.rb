WebAuthn.configure do |config|
  config.algorithms.concat(["ES384", "ES512", "PS256", "PS384", "PS512"])
end

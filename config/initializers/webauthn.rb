WebAuthn.configure do |config|
  config.algorithms.concat(%w(ES384 ES512 PS256 PS384 PS512 RS384 RS512 RS1))
end

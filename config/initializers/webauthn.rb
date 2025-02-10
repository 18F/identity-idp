# frozen_string_literal: true

WebAuthn.configure do |config|
  config.algorithms.concat(%w[ES384 ES512 PS384 PS512])
end

# frozen_string_literal: true

module Encryption
  # The payload failed authentication: either the key is wrong or the ciphertext was modified.
  class DecipherError < EncryptionError
  end
end

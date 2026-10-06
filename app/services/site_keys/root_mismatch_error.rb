# frozen_string_literal: true

module SiteKeys
  # The root is wrapped under a different secret than the one given.
  class RootMismatchError < Encryption::EncryptionError
  end
end

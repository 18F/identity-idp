# frozen_string_literal: true

module SiteKeys
  # The site key is wrapped under a different secret than the one given.
  class MismatchError < Encryption::EncryptionError
  end
end

# frozen_string_literal: true

require 'base64'

module Digest
  # ideally we could patch onto one of the mixins like Instance but that didn't seem to work
  class SHA256
    def self.urlsafe_base64digest(str = nil)
      Base64.urlsafe_encode64(digest(str), padding: false)
    end
  end
end

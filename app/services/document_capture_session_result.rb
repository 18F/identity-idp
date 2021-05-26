# frozen_string_literal: true

# This is used by hybrid doc auth capture
DocumentCaptureSessionResult =
  RedactedStruct.new(:id, :success, :pii, keyword_init: true, allowed_members: %i[id success]) do
    def self.redis_key_prefix
      'dcs:result'
    end

    alias_method :success?, :success
    alias_method :pii_from_doc, :pii
  end

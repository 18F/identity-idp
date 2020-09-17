# frozen_string_literal: true

DocumentCaptureSessionResult = Struct.new(:id, :success, :pii, keyword_init: true) do
  def self.redis_key_prefix
    'dcs:result'
  end

  alias_method :success?, :success
end

# frozen_string_literal: true

HealthCheckSummary = Struct.new(:healthy, :result, keyword_init: true) do
  def as_json(*args)
    to_h.as_json(*args)
  end

  alias_method :healthy?, :healthy
end

module JobRunner
  HealthCheckerSummary = Struct.new(:healthy, :result) do
    def as_json(*args)
      to_h.as_json(*args)
    end

    alias_method :healthy?, :healthy
  end
end

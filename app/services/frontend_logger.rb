class FrontendLogger
  attr_reader :analytics, :error_logger, :event_map

  # @param [Analytics] analytics
  # @param [FrontendErrorLogger] error_logger
  # @param [Hash{String=>Symbol,Method}] event_map
  def initialize(analytics:, error_logger:, event_map:)
    @analytics = analytics
    @error_logger = error_logger
    @event_map = event_map
  end

  # @param [String] name
  # @param [Hash] attributes
  def track_event(name, attributes)
    target_class, analytics_method = event_map[name]

    # case/when doesn't work because === on classes is an instance check, not identity
    target = if target_class == Analytics
      analytics
    elsif target_class == FrontendErrorLogger
      error_logger
    end

    if analytics_method
      target.send(
        analytics_method,
        **hash_from_method_kwargs(attributes, target.method(analytics_method)),
      )
    else
      analytics.track_event("Frontend: #{name}", attributes)
    end
  end

  private

  def hash_from_method_kwargs(hash, method)
    method_kwargs(method).index_with { |key| hash[key.to_s] }
  end

  def method_kwargs(method)
    method.
      parameters.
      map { |type, name| name if [:key, :keyreq].include?(type) }.
      compact
  end
end

class FrontendLogger
  attr_reader :analytics, :event_map

  # @param [Analytics] analytics
  # @param [Hash{String=>Symbol,#call}] event_map map of string event names to method names
  #   on Analytics, or a custom implementation that's callable (like a Proc or Method)
  def initialize(analytics:, event_map:)
    @analytics = analytics
    @event_map = event_map
  end

  # Logs an event and converts the payload to the correct keyword args
  # @param [String] name
  # @param [Hash<String,Object>] attributes payload with string keys
  def track_event(name, attributes)
    analytics_method = event_map[name]

    if analytics_method.is_a?(Symbol)
      analytics.send(
        analytics_method,
        **hash_from_kwargs(attributes, AnalyticsEvents.instance_method(analytics_method)),
      )
    elsif analytics_method.respond_to?(:call)
      analytics_method.call(**hash_from_kwargs(attributes, analytics_method))
    else
      analytics.track_event("Frontend: #{name}", attributes)
    end
  end

  private

  # @param [Hash<String,Object>] hash
  # @param [Proc,Method] callable
  # @return [Hash<Symbol,Object>]
  def hash_from_kwargs(hash, callable)
    kwargs(callable).index_with { |key| hash[key.to_s] }
  end

  # @param [Proc,Method] callable
  # @return [Array<Symbol>] the names of the kwargs for the callable (both optional and required)
  def kwargs(callable)
    callable.
      parameters.
      map { |type, name| name if [:key, :keyreq].include?(type) }.
      compact
  end
end

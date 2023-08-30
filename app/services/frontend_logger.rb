class FrontendLogger
  attr_reader :analytics, :event_map

  # @param [Analytics]
  # @param [Hash{String=>UnboundMethod,Proc}]
  def initialize(analytics:, event_map:)
    @analytics = analytics
    @event_map = event_map
  end

  # @param [String] name
  # @param [Hash] attributes
  def track_event(name, attributes)
    analytics_method = event_map[name]
    case analytics_method
    when Symbol
      analytics.send(
        analytics_method,
        **hash_from_method_kwargs(attributes, analytics.method(analytics_method)),
      )
    when Method
      analytics_method.call(**hash_from_method_kwargs(attributes, analytics_method))
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

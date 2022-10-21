class FrontendLogger
  attr_reader :analytics, :event_map

  def initialize(analytics:, event_map:)
    @analytics = analytics
    @event_map = event_map
  end

  def track_event(name, attributes)
    if (analytics_method = event_map[name])
      analytics.send(analytics_method.name, **hash_from_method_kwargs(attributes, analytics_method))
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

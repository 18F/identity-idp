class NullAhoyTracker
  def set_visitor_cookie
    # no-op
  end

  def set_visit_cookie
    # no-op
  end

  def new_visit?
    true
  end

  def track_visit(_options = {})
    # no-op
  end

  def track(_name, _properties = {}, _options = {})
    # no-op
  end
end

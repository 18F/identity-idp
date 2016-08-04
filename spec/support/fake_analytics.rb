class FakeAnalytics
  def track_event(event, subject = user)
  end

  def track_anonymous_event(event, attribute = nil)
  end

  def track_pageview
  end
end

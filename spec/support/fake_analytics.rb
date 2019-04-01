class FakeAnalytics
  def track_event(_event, _attributes = {})
    # no-op
  end

  def track_mfa_submit_event(_event, _attributes = {})
    # no-op
  end
end

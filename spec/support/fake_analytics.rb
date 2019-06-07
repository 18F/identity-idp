class FakeAnalytics
  def track_event(_event, _attributes = {})
    # no-op
  end

  def track_mfa_submit_event(_attributes, _ga_client_id)
    # no-op
  end

  def grab_ga_client_id
    '123.456'
  end
end

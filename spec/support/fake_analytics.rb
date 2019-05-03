class FakeAnalytics
  def track_event(_event, _attributes = {})
    # no-op
  end

  def track_mfa_submit_event(_attributes, _ga_client_id)
    # no-op
  end

  def grab_ga_client_id
    'abc-cool-town-5'
  end
end

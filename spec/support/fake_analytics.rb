class FakeAnalytics
  attr_reader :events

  def initialize
    @events = Hash.new { |hash, key| hash[key] = [] }
  end

  def track_event(event, attributes = {})
    events[event] << attributes
    nil
  end

  def track_mfa_submit_event(_attributes)
    # no-op
  end

  def allowable_frontend_events
    [
      Analytics::FRONTEND_DOC_AUTH_ASYNC_UPLOAD,
      Analytics::FRONTEND_DOC_AUTH_ACUANT_WEB_SDK_RESULT,
    ]
  end
end

RSpec::Matchers.define :have_logged_event do |event_name, attributes|
  match do |actual|
    expect(actual).to be_kind_of(FakeAnalytics)

    expect(actual.events[event_name]).to(be_any { |event| attributes <= event })
  end

  failure_message do |actual|
    <<~MESSAGE
      Expected that FakeAnalytics would have received event #{event_name.inspect}
      with #{attributes.inspect}.

      Events received:
      #{actual.events.pretty_inspect}
    MESSAGE
  end
end

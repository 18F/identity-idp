class FakeAnalytics
  attr_reader :events

  def initialize
    @events = Hash.new { |hash, key| hash[key] = [] }
  end

  def track_event(event, attributes = {})
    events[event] << attributes
    nil
  end

  def track_mfa_submit_event(_attributes, _ga_client_id)
    # no-op
  end

  def grab_ga_client_id
    '123.456'
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

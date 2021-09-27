class FakeAnalytics
  PiiDetected = Class.new(StandardError)

  module PiiAlerter
    def track_event(event, attributes = {})
      raise PiiDetected, 'pii detected in analytics' if attributes.to_json.include?('pii')

      pii_attr_names = Pii::Attributes.members.map(&:to_s)

      check_recursive = ->(value) do
        case value
        when String, Symbol
          if pii_attr_names.include?(value.to_s.downcase)
            raise PiiDetected, "pii key #{value} passed to track_event"
          end
        when Hash, Array
          value.each(&check_recursive)
        end
      end

      attributes.each(&check_recursive)

      super(event, attributes)
    end
  end

  prepend PiiAlerter

  attr_reader :events

  def initialize
    @events = Hash.new
  end

  def track_event(event, attributes = {})
    events[event] ||= []
    events[event] << attributes
    nil
  end

  def track_mfa_submit_event(_attributes)
    # no-op
  end

  def browser_attributes
    {}
  end
end

RSpec::Matchers.define :have_logged_event do |event_name, attributes|
  attributes ||= {}

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

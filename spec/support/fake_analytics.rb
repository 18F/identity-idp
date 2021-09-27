class FakeAnalytics
  PiiDetected = Class.new(StandardError)

  module PiiAlerter
    def track_event(event, attributes = {})
      pii_like_keypaths = attributes.delete(:pii_like_keypaths) || []

      if attributes.to_json.include?('pii')
        raise PiiDetected, "pii detected in analytics, full event: #{attributes}"
      end

      pii_attr_names = Pii::Attributes.members

      check_recursive = ->(value, keypath = []) do
        case value
        when Hash
          value.each do |key, val|
            if pii_attr_names.include?(key) && !pii_like_keypaths.include?(keypath + [key])
              raise PiiDetected, "pii key #{value} passed to track_event, full event: #{attributes}"
            end

            check_recursive.call(val, [key])
          end
        when Array
          value.each(&check_recursive)
        end
      end

      check_recursive.call(attributes)

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

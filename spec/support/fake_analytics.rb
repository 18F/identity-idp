class FakeAnalytics
  PiiDetected = Class.new(StandardError)

  module PiiAlerter
    def track_event(event, attributes = {})
      pii_like_keypaths = attributes.delete(:pii_like_keypaths) || []

      if attributes.to_json.include?('pii') && !pii_like_keypaths.include?([:pii])
        raise PiiDetected, "string 'pii' detected in analytics, full event: #{attributes}"
      end

      pii_attr_names = Pii::Attributes.members - [
        :state, # state on its own is not enough to be a pii leak
      ]
      constant_name = Analytics.constants.find { |c| Analytics.const_get(c) == event }

      check_recursive = ->(value, keypath = []) do
        case value
        when Hash
          value.each do |key, val|
            current_keypath = keypath + [key]
            if pii_attr_names.include?(key) && !pii_like_keypaths.include?(current_keypath)
              raise PiiDetected, <<~ERROR
                track_event received pii key path: #{current_keypath.inspect}
                event: #{event} (#{constant_name})
                full event: #{attributes.inspect}
                allowlisted keypaths: #{pii_like_keypaths.inspect}
              ERROR
            end

            check_recursive.call(val, [key])
          end
        when Array
          value.each { |val| check_recursive.call(val, keypath) }
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

class FakeAnalytics < Analytics
  PiiDetected = Class.new(StandardError)

  include AnalyticsEvents
  prepend Idv::AnalyticsEventsEnhancer

  module PiiAlerter
    def track_event(event, original_attributes = {})
      attributes = original_attributes.dup
      pii_like_keypaths = attributes.delete(:pii_like_keypaths) || []

      constant_name = Analytics.constants.find { |c| Analytics.const_get(c) == event }

      string_payload = attributes.to_json

      if string_payload.include?('pii') && !pii_like_keypaths.include?([:pii])
        raise PiiDetected, <<~ERROR
          track_event string 'pii' detected in attributes
          event: #{event} (#{constant_name})
          full event: #{attributes}"
        ERROR
      end

      Idp::Constants::MOCK_IDV_APPLICANT.slice(
        :first_name,
        :last_name,
        :address1,
        :zipcode,
        :dob,
        :state_id_number,
      ).each do |key, default_pii_value|
        if string_payload.match?(Regexp.new('\b' + Regexp.quote(default_pii_value) + '\b', 'i'))
          raise PiiDetected, <<~ERROR
            track_event example PII #{key} (#{default_pii_value}) detected in attributes
            event: #{event} (#{constant_name})
            full event: #{attributes}"
          ERROR
        end
      end

      pii_attr_names = Pii::Attributes.members + [:personal_key] - [
        :state, # state on its own is not enough to be a pii leak
      ]

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
  attr_accessor :user

  def initialize(user: AnonymousUser.new)
    @events = Hash.new
    @user = user
  end

  def track_event(event, attributes = {})
    events[event] ||= []
    events[event] << attributes
    nil
  end

  def track_mfa_submit_event(_attributes)
    # no-op
  end

  # no-op this event in fake analytics, because it adds a lot of noise to tests
  # expecting other events
  def irs_attempts_api_event_metadata(**_attrs)
    # no-op
  end

  def browser_attributes
    {}
  end
end

RSpec::Matchers.define :have_logged_event do |event_name, attributes|
  attributes ||= {}

  match do |actual|
    if RSpec::Support.is_a_matcher?(attributes)
      expect(actual.events[event_name]).to include(attributes)
    else
      expect(actual.events[event_name]).to(be_any { |event| attributes.as_json <= event.as_json })
    end
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

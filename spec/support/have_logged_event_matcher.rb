require 'rspec/matchers/built_in/count_expectation'

class HaveLoggedEventMatcher
  include RSpec::Matchers::Composable
  include RSpec::Matchers::BuiltIn::CountExpectation

  attr_reader :hash_including_equals_failure_message

  def initialize(
    expected_event_name: nil,
    expected_attributes: nil
  )
    @expected_event_name = expected_event_name
    @expected_attributes = expected_attributes
  end

  def failure_message
    return hash_including_equals_failure_message if hash_including_equals_failure_message.present?
    return fake_analytics_missing_failure_message if fake_analytics_missing?

    matching_events = events[expected_event_name]

    if matching_events&.length == 1
      failure_message_with_diff(matching_events.first)
    else
      default_failure_message
    end
  end

  def failure_message_when_negated
    return fake_analytics_missing_failure_message if fake_analytics_missing?

    adjective = attributes_matcher_description(expected_attributes) ? 'matching ' : ''
    [
      "Expected that FakeAnalytics would not have received #{adjective}event",
      expected_event_name.inspect,
      has_expected_count? ? count_failure_reason('it was received').strip : nil,
    ].compact.join(' ')
  end

  def matches?(actual)
    @actual = actual

    return false if fake_analytics_missing?

    matched_events =
      if expected_event_name.nil? && expected_attributes.nil?
        events.values.flatten
      elsif expected_attributes.nil?
        events[expected_event_name] || []
      else
        (events[expected_event_name] || []).filter do |actual_attributes|
          values_match?(expected_attributes, actual_attributes) &&
            !hash_including_equals(expected_attributes, actual_attributes)
        end
      end

    if has_expected_count?
      expected_count_matches?(matched_events.length)
    else
      matched_events.length > 0
    end
  end

  private

  attr_reader :expected_event_name, :expected_attributes

  def fake_analytics_missing?
    !@actual.is_a?(FakeAnalytics)
  end

  def hash_including_equals(expected_attributes, actual_attributes)
    if expected_attributes.instance_of?(RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher) &&
       expected_attributes.instance_variable_get(:@expected) == actual_attributes &&
       !in_shared_example?
      @hash_including_equals_failure_message = <<~STR
        Unexpected use of hash_including when included attributes are exactly equal to actual attributes

        Strict equality is preferred over hash_including except when intentionally testing a hash including more than properties than what's asserted

        Expected: #{expected_attributes.instance_variable_get(:@expected)}
        Actual:   #{actual_attributes}
      STR
      true
    else
      false
    end
  end

  def in_shared_example?
    RSpec.current_example.metadata[:shared_group_inclusion_backtrace].present?
  end

  def fake_analytics_missing_failure_message
    <<~STR
      Matching expected logged events requires analytics to be stubbed.

      Check that you've called `stub_analytics` before asserting `have_logged_event`.
    STR
  end

  def default_failure_message
    with_attributes = expected_attributes.nil? ?
      nil :
      "with #{format_attributes(expected_attributes)}"

    received = <<~RECEIVED

      Events received:
      #{events.pretty_inspect}
    RECEIVED

    [
      expectation_description,
      with_attributes,
      received,
    ].compact.join("\n")
  end

  def differ
    RSpec::Support::Differ.new(
      object_preparer: ->(object) { RSpec::Matchers::Composable.surface_descriptions_in(object) },
      color: RSpec::Matchers.configuration.color?,
    )
  end

  def events
    if @actual.respond_to?(:events)
      @actual.events
    else
      @actual
    end
  end

  def expectation_description
    adjective = attributes_matcher_description(expected_attributes) ? 'matching ' : ''
    [
      "Expected that FakeAnalytics would have received #{adjective}event",
      expected_event_name.inspect,
      has_expected_count? ? count_failure_reason('it was received').strip : nil,
    ].compact.join(' ')
  end

  def expected_attributes_hash
    resolve_attributes_hash(expected_attributes)
  end

  def attributes_matcher_description(attributes)
    if attributes.instance_of?(RSpec::Matchers::BuiltIn::Include)
      'include'
    elsif attributes.instance_of?(RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher)
      'hash_including'
    end
  end

  def diff_description(actual_attributes)
    <<~DIFF
      expected: #{format_attributes(expected_attributes)}
           got: #{format_attributes(actual_attributes)}

      Diff:#{differ.diff(actual_attributes, expected_attributes_hash)}
    DIFF
  end

  def failure_message_with_diff(actual_attributes)
    [
      expectation_description,
      diff_description(actual_attributes),
      ignored_attributes_description(actual_attributes),
    ].compact.join("\n")
  end

  def format_attributes(attributes)
    return '' if attributes.nil?

    desc = attributes_matcher_description(attributes)
    resolved_attributes = resolve_attributes_hash(attributes)

    if desc
      args = resolved_attributes.keys.map do |key|
        "#{key}: #{resolved_attributes[key].inspect}"
      end.join(', ')

      "#{desc}(#{args})"
    else
      resolved_attributes.inspect
    end
  end

  def ignored_attributes_description(actual_attributes)
    using_matcher = expected_attributes && !expected_attributes.instance_of?(Hash)
    return if !using_matcher

    ignored_attributes = actual_attributes.except(*expected_attributes_hash.keys)
    return if ignored_attributes.empty?

    diff = differ.diff(ignored_attributes, {})

    "Attributes ignored by the include matcher: #{diff}"
  end

  def resolve_attributes_hash(attributes)
    if attributes.instance_of?(RSpec::Matchers::BuiltIn::Include)
      attributes.expecteds.first
    elsif attributes.instance_of?(RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher)
      attributes.instance_variable_get(:@expected)
    else
      attributes
    end
  end
end

module RSpec::Matchers
  def have_logged_event(expected_event_name = nil, expected_attributes = nil)
    HaveLoggedEventMatcher.new(expected_event_name:, expected_attributes:)
  end
end

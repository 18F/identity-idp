require 'rspec/matchers/built_in/count_expectation'

class HaveLoggedEventMatcher
  include RSpec::Matchers::Composable
  include RSpec::Matchers::BuiltIn::CountExpectation

  def initialize(
    expected_event_name: nil,
    expected_attributes: nil
  )
    @expected_event_name = expected_event_name
    @expected_attributes = expected_attributes
  end

  def failure_message
    matching_events = events[expected_event_name]

    attributes_hash = expected_attributes.instance_of?(Hash) && expected_attributes
    include_matcher =
      expected_attributes.instance_of?(RSpec::Matchers::BuiltIn::Include) && expected_attributes
    hash_including_matcher =
      expected_attributes.instance_of?(RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher) &&
      expected_attributes

    if matching_events&.length == 1 && attributes_hash
      failure_message_with_diff(
        actual_attributes: matching_events.first,
        expected_attributes: attributes_hash,
      )
    elsif matching_events&.length == 1 && include_matcher
      failure_message_with_diff(
        actual_attributes: matching_events.first,
        expected_attributes: include_matcher.expecteds.first,
        ignored_attributes: matching_events.first.except(*include_matcher.expecteds.first.keys),
        match_type: 'include',
      )
    elsif matching_events&.length == 1 && hash_including_matcher
      failure_message_with_diff(
        actual_attributes: matching_events.first,
        expected_attributes: hash_including_matcher.instance_variable_get(:@expected),
        match_type: 'hash including',
      )
    else
      default_failure_message
    end
  end

  def matches?(actual)
    @actual = actual

    matched_events =
      if expected_event_name.nil? && expected_attributes.nil?
        events.values.flatten
      elsif expected_attributes.nil?
        events[expected_event_name] || []
      else
        (events[expected_event_name] || []).filter do |actual_attributes|
          values_match?(expected_attributes, actual_attributes)
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

  def default_failure_message
    with_attributes = expected_attributes.nil? ? nil : "with #{expected_attributes.inspect}"

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

  def expectation_description(adjective = nil)
    adjective = adjective ? "#{adjective} " : ''
    [
      "Expected that FakeAnalytics would have received #{adjective}event",
      expected_event_name.inspect,
      has_expected_count? ? count_failure_reason('it was received').strip : nil,
    ].compact.join(' ')
  end

  def failure_message_with_diff(
    expected_attributes:,
    actual_attributes:,
    ignored_attributes: {},
    match_type: nil
  )
    match_type = match_type ? "#{match_type} " : ''

    [
      <<~MESSAGE.strip,
        #{expectation_description(match_type ? "matching" : nil)}
        expected: #{match_type}#{expected_attributes}
             got: #{actual_attributes}

        Diff:#{differ.diff(actual_attributes, expected_attributes)}
      MESSAGE

      ignored_attributes && ignored_attributes.empty? ? nil : <<~DIFF.strip,
        Attributes ignored by the include matcher:#{differ.diff(ignored_attributes, {})}
      DIFF
    ].compact.join("\n")
  end
end

module RSpec::Matchers
  def have_logged_event(expected_event_name = nil, expected_attributes = nil)
    HaveLoggedEventMatcher.new(expected_event_name:, expected_attributes:)
  end
end

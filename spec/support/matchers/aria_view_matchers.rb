class HaveButtonToWithAccessibilityMatcher
  attr_reader :expected_button_text, :expected_action, :expected_aria_label, :actual

  def initialize(expected_button_text,
                 expected_action,
                 expected_aria_label = expected_button_text)
    @expected_button_text = expected_button_text
    @expected_aria_label = expected_aria_label
    @expected_action = expected_action
  end

  def match(actual_text)
    @actual ||= Capybara.string(actual_text)

    button && enclosing_form && aria_label_ok? && action_ok?
  end

  def failure_message(actual_text)
    @actual ||= Capybara.string(actual_text)
    return "expected to find button with text '#{expected_button_text}'" unless button
    return 'expected button to be in a (Rails) "button_to" form tag' unless enclosing_form

    message = ''
    message += aria_label_failure_message unless aria_label_ok?
    message += action_failure_message unless action_ok?
    message
  end

  private

  def button
    puts "expected_button_text: #{expected_button_text.inspect}"

    actual.find_button(expected_button_text)
  rescue Capybara::ElementNotFound
    return nil
  end

  def enclosing_form
    button&.ancestor('form.button_to')
  rescue Capybara::ElementNotFound
    return nil
  end

  def aria_label_ok?
    enclosing_form && enclosing_form['aria-label'] == expected_aria_label
  end

  def aria_label_failure_message
    "expected enclosing form to have an 'aria-label' attribute with value '#{expected_aria_label}'"
  end

  def action_ok?
    enclosing_form && enclosing_form['action'] == expected_action
  end

  def action_failure_message
    "expected enclosing form to have an 'action' attribute with value '#{expected_action}'"
  end
end

RSpec::Matchers.define :have_button_to_with_accessibility do |expected_button_text, expected_action|
  matcher = HaveButtonToWithAccessibilityMatcher.new(expected_button_text, expected_action)
  match { |actual_text| matcher.match(actual_text) }
  failure_message { |actual_text| matcher.failure_message(actual_text) }
end

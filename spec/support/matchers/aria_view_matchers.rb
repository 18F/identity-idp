# Very minimal start on accessibility matchers for view specs.
# Defines one matcher, specific to buttons generated with Rails'
# `button_to` helper
#
# Matcher: `have_button_to_with_accessibility`
# Use:
#
# expect(rendered).to have_button_to_with_accessibility('expected button text',
#                                                       'expected button action')
# or
#
# expect(rendered).to have_button_to_with_accessibility('expected button text',
#                                                       'expected button action',
#                                                       'expected aria label')
#
# In the first case, the expected aria-label attribute value will be
# the expected button text.

class HaveButtonToWithAccessibilityMatcher
  attr_reader :expected_button_text, :expected_action, :expected_aria_label, :actual

  def initialize(expected_button_text,
                 expected_action,
                 expected_aria_label)
    @expected_button_text = expected_button_text
    @expected_aria_label = expected_aria_label
    @expected_action = expected_action
  end

  def match(actual_text)
    @actual = Capybara.string(actual_text.strip)

    button && enclosing_form && aria_label_ok? && action_ok?
  end

  def failure_message(_actual_text)
    return "expected to find button with text '#{expected_button_text}'" unless button
    return 'expected button to be in a (Rails) "button_to" form tag' unless enclosing_form

    messages = []
    messages += aria_label_failure_message unless aria_label_ok?
    messages += action_failure_message unless action_ok?
    messages.join("\n")
  end

  private

  def button
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

RSpec::Matchers.define :have_button_to_with_accessibility do |expected_button_text,
                                                              expected_action,
                                                              expected_aria_label =
                                                                expected_button_text|
  matcher = HaveButtonToWithAccessibilityMatcher.new(
    expected_button_text,
    expected_action,
    expected_aria_label,
  )

  match { |actual_text| matcher.match(actual_text) }
  failure_message { |actual_text| matcher.failure_message(actual_text) }
end

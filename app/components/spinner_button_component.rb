# frozen_string_literal: true

class SpinnerButtonComponent < BaseComponent
  attr_reader :action_message, :button_options, :outline, :spin_on_click

  # @param [String] action_message Message describing the action being performed, shown visually to
  #                                users when the animation has been active for a long time, and
  #                                immediately to users of assistive technology.
  def initialize(action_message: nil, spin_on_click: nil, **button_options)
    @action_message = action_message
    @button_options = button_options
    @outline = button_options[:outline]
    @spin_on_click = spin_on_click
  end

  def css_class
    'spinner-button--outline' if outline
  end
end

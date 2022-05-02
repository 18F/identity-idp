class SpinnerButtonComponent < BaseComponent
  attr_reader :action_message, :button_options

  # @param [String] action_message Message describing the action being performed, shown visually to
  #                                users when the animation has been active for a long time, and
  #                                immediately to users of assistive technology.
  def initialize(action_message: nil, **button_options)
    @action_message = action_message
    @button_options = button_options
  end
end

class SpinnerButtonComponent < BaseComponent
  DEFAULT_LONG_WAIT_DURATION = 15.seconds

  attr_reader :action_message,
              :button_options,
              :outline,
              :long_wait_duration,
              :spin_on_click,
              :wrapper_options

  # @param [String] action_message Message describing the action being performed, shown visually to
  #                                users when the animation has been active for a long time, and
  #                                immediately to users of assistive technology.
  # @param [Boolean] spin_on_click Whether to start the spinning animation immediately on click.
  # @param [ActiveSupport::Duration] long_wait_duration Time until the action message becomes
  # visible.
  def initialize(
    action_message: nil,
    spin_on_click: nil,
    long_wait_duration: DEFAULT_LONG_WAIT_DURATION,
    wrapper_options: {},
    **button_options
  )
    @action_message = action_message
    @button_options = button_options
    @outline = button_options[:outline]
    @long_wait_duration = long_wait_duration
    @spin_on_click = spin_on_click
    @wrapper_options = wrapper_options
  end

  def css_class
    classes = [*wrapper_options[:class]]
    classes << 'spinner-button--outline' if outline
    classes
  end
end

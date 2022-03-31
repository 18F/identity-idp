class FailurePresenter
  attr_reader :state

  STATE_CONFIG = {
    failure: {
      icon: 'alert/fail-x.svg',
      color: 'red',
    },
    locked: {
      icon: 'alert/temp-lock.svg',
      color: 'red',
    },
    warning: {
      icon: 'alert/warning-lg.svg',
      color: 'yellow',
    },
  }.freeze

  def initialize(state)
    @state = state
  end

  def state_icon
    STATE_CONFIG.dig(state, :icon)
  end

  def state_color
    STATE_CONFIG.dig(state, :color)
  end

  def title; end

  def header; end

  def description(_view_context); end

  def troubleshooting_options
    []
  end

  def js; end
end

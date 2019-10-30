class FailurePresenter
  attr_reader :state

  STATE_CONFIG = {
    failure: {
      icon: 'alert/fail-x.svg',
      alt_text: 'failure',
      color: 'red',
    },
    locked: {
      icon: 'alert/temp-lock.svg',
      alt_text: 'locked',
      color: 'red',
    },
    warning: {
      icon: 'alert/warning-lg.svg',
      alt_text: 'warning',
      color: 'yellow',
    },
    are_you_sure: {
      icon: 'alert/forgot.svg',
      alt_text: 'warning',
      color: 'teal',
    },
  }.freeze

  def initialize(state)
    @state = state
  end

  def state_icon
    STATE_CONFIG.dig(state, :icon)
  end

  def state_alt_text
    STATE_CONFIG.dig(state, :alt_text)
  end

  def state_color
    STATE_CONFIG.dig(state, :color)
  end

  def message; end

  def title; end

  def header; end

  def description; end

  def next_steps
    []
  end

  def js; end
end

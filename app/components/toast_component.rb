# frozen_string_literal: true

class ToastComponent < BaseComponent
  DEFAULT_SHOW_DELAY_MS = 500
  DEFAULT_DISMISS_AFTER_MS = 3000

  attr_reader :message, :show_delay, :dismiss_after, :tag_options

  def initialize(
    message: nil,
    show_delay: DEFAULT_SHOW_DELAY_MS,
    dismiss_after: DEFAULT_DISMISS_AFTER_MS,
    **tag_options
  )
    @message = message
    @show_delay = show_delay
    @dismiss_after = dismiss_after
    @tag_options = tag_options
  end

  def content
    @message || super
  end

  def css_class
    ['ads-toast', *tag_options[:class]]
  end
end

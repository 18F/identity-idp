# frozen_string_literal: true

module NDS
  # Net-new NDS toast; renders only in the NDS bucket. Emits an
  # <lg-toast class="toast"> announcement with a check icon and message text.
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
      ['toast', *tag_options[:class]]
    end
  end
end

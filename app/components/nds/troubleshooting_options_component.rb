# frozen_string_literal: true

module NDS
  # Net-new NDS troubleshooting options (nds bucket only): the auth-flow
  # replacement for TroubleshootingOptionsComponent. Renders a heading over a
  # stack of tertiary ButtonComponents (Figma "links" in auth flows are
  # tertiary buttons; an option may set variant: to promote itself), with
  # new-tab options opened in a new window and announced to screen readers.
  class TroubleshootingOptionsComponent < BaseComponent
    Option = Struct.new(:text, :url, :new_tab, :method, :variant, keyword_init: true)

    attr_reader :heading, :options, :heading_level

    def initialize(heading:, options:, heading_level: :h2)
      @heading = heading
      @options = options.map { |option| Option.new(**option.to_h.slice(*Option.members)) }
      @heading_level = heading_level
    end

    def render?
      options.present?
    end

    def button_for(option)
      ButtonComponent.new(
        url: option.url,
        method: option.method,
        variant: option.variant || :tertiary,
        full_width: true,
        **(option.new_tab ? { target: '_blank', rel: 'noopener' } : {}),
      )
    end
  end
end

# frozen_string_literal: true

module NDS
  # Net-new NDS top chrome (renders only in the nds layout). Emits the gov
  # banner and logo banner inside .auth-page__top-chrome, plus an optional
  # progress slot.
  #
  # NOTE (idp gap, flagged): idp has no dedicated official-banner component and
  # no route-map progress helper, so this reuses idp's existing shared/banner
  # partial and exposes progress only as an explicit slot (no auto-progress).
  # Revisit when the NDS progress/step-indicator lands.
  class PageChromeComponent < BaseComponent
    renders_one :trailing
    renders_one :progress

    attr_reader :hide_logo, :hide_banner

    def initialize(hide_logo: false, hide_banner: false)
      @hide_logo = hide_logo
      @hide_banner = hide_banner
    end
  end
end

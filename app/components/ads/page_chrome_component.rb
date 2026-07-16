# frozen_string_literal: true

module ADS
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

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
  #
  # On service-provider-initiated pages, pass agency_logo_url (and
  # agency_name for its alt text) to co-brand the header: the Login.gov logo,
  # a 1px rule, then the partner's 24px seal (DS .auth-page__logo-banner-agency).
  class PageChromeComponent < BaseComponent
    renders_one :trailing
    renders_one :progress

    attr_reader :hide_logo, :hide_banner, :agency_name, :agency_logo_url

    def initialize(hide_logo: false, hide_banner: false, agency_name: nil, agency_logo_url: nil)
      @hide_logo = hide_logo
      @hide_banner = hide_banner
      @agency_name = agency_name
      @agency_logo_url = agency_logo_url
    end

    def agency?
      agency_logo_url.present?
    end
  end
end

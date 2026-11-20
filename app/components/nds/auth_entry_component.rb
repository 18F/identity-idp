# frozen_string_literal: true

module NDS
  # Net-new NDS auth-entry scaffold (nds bucket only). Two-column sign-in/
  # create-account entry wrapper: decorative blurs + marketing aside + card
  # holding the form content. Unprefixed classes (auth-entry*); blurs.svg
  # resolves from the design-system img path.
  class AuthEntryComponent < BaseComponent
    # Auth-entry cards show the agency seal themselves, so this tells the NDS
    # layout to leave the agency out of the top chrome (Figma shows only the
    # Login.gov logo above the card on mobile, where that chrome is visible).
    def before_render
      super
      helpers.content_for(:nds_auth_entry, 'true')
    end
  end
end

# frozen_string_literal: true

module NDS
  # NDS passkey / security key verify button; renders only in the NDS bucket.
  # Emits the same lg-webauthn-verify-button contract as the default
  # WebauthnVerifyButtonComponent (spinner, webauthn-verify-button__button
  # submit, and the hidden credential/assertion inputs) so the existing custom
  # element drives it unchanged, but without the default experience's
  # display-block/margin-y-3 spacing, leaving layout to the NDS action stack.
  # The default WebauthnVerifyButtonComponent is unaffected.
  class WebauthnVerifyButtonComponent < BaseComponent
    attr_reader :credentials, :user_challenge, :tag_options

    # Reuse the default component's pack rather than adding a same-named NDS
    # sidecar: webpack keys entries by basename, so a second
    # webauthn_verify_button_component.ts would collide (see webpack.config.js).
    def self.scripts
      super + ::WebauthnVerifyButtonComponent.scripts
    end

    def initialize(credentials:, user_challenge:, **tag_options)
      @credentials = credentials
      @user_challenge = user_challenge
      @tag_options = tag_options
    end
  end
end

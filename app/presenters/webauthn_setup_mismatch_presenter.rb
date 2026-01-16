# frozen_string_literal: true

class WebauthnSetupMismatchPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :configuration

  def initialize(configuration:)
    @configuration = configuration
  end

  def heading
    if platform_authenticator?
      t('webauthn_setup_mismatch.heading.webauthn_platform')
    else
      t('webauthn_setup_mismatch.heading.webauthn')
    end
  end

  def description
    if platform_authenticator?
      t('webauthn_setup_mismatch.description.webauthn_platform')
    else
      t('webauthn_setup_mismatch.description.webauthn')
    end
  end

  def correct_image_path
    if platform_authenticator?
      'webauthn-mismatch/webauthn-platform-checked.svg'
    else
      'webauthn-mismatch/webauthn-checked.svg'
    end
  end

  def incorrect_image_path
    if platform_authenticator?
      'webauthn-mismatch/webauthn-unchecked.svg'
    else
      'webauthn-mismatch/webauthn-platform-unchecked.svg'
    end
  end

  private

  delegate :platform_authenticator?, to: :configuration
end

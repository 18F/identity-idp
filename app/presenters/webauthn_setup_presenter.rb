class WebauthnSetupPresenter < SetupPresenter
  include ActionView::Helpers::TranslationHelper

  def initialize(
    current_user:,
    user_fully_authenticated:,
    user_opted_remember_device_cookie:,
    remember_device_default:,
    platform_authenticator:
  )
    super(
      current_user: current_user,
      user_fully_authenticated: user_fully_authenticated,
      user_opted_remember_device_cookie: user_opted_remember_device_cookie,
      remember_device_default: remember_device_default,
    )

    @platform_authenticator = platform_authenticator
  end

  def image_path
    if @platform_authenticator
      'platform-authenticator.svg'
    else
      'security-key.svg'
    end
  end

  def heading
    if @platform_authenticator
      t('headings.webauthn_platform_setup.new')
    else
      t('headings.webauthn_setup.new')
    end
  end

  def intro
    if @platform_authenticator
      t('forms.webauthn_platform_setup.intro_html')
    else
      t('forms.webauthn_setup.intro_html')
    end
  end

  def nickname_label
    if @platform_authenticator
      t('forms.webauthn_platform_setup.nickname')
    else
      t('forms.webauthn_setup.nickname')
    end
  end

  def button_text
    if @platform_authenticator
      t('forms.webauthn_platform_setup.continue')
    else
      t('forms.webauthn_setup.continue')
    end
  end

  def setup_heading
    if @platform_authenticator
      t('forms.webauthn_platform_setup.instructions_title')
    else
      t('forms.webauthn_setup.instructions_title')
    end
  end

  def setup_instructions
    if @platform_authenticator
      t('forms.webauthn_platform_setup.instructions_text', app_name: APP_NAME)
    else
      t('forms.webauthn_setup.instructions_text', app_name: APP_NAME)
    end
  end
end

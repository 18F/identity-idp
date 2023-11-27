class WebauthnSetupPresenter < SetupPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TranslationHelper

  attr_reader :url_options, :user

  def initialize(
    current_user:,
    user_fully_authenticated:,
    user_opted_remember_device_cookie:,
    remember_device_default:,
    platform_authenticator:,
    url_options:
  )
    super(
      current_user: current_user,
      user_fully_authenticated: user_fully_authenticated,
      user_opted_remember_device_cookie: user_opted_remember_device_cookie,
      remember_device_default: remember_device_default,
    )

    @user = current_user
    @platform_authenticator = platform_authenticator
    @url_options = url_options
  end

  def image_path
    if @platform_authenticator
      'platform-authenticator.svg'
    else
      'security-key.svg'
    end
  end

  def page_title
    if @platform_authenticator
      t('headings.webauthn_platform_setup.new')
    else
      t('titles.webauthn_setup')
    end
  end

  def heading
    if @platform_authenticator
      t('headings.webauthn_platform_setup.new')
    else
      t('headings.webauthn_setup.new')
    end
  end

  def device_nickname_hint
    if @platform_authenticator
      t('forms.webauthn_platform_setup.nickname_hint')
    end
  end

  def intro_html
    if @platform_authenticator
      t(
        'forms.webauthn_platform_setup.intro_html',
        app_name: APP_NAME,
        link: link_to(
          t('forms.webauthn_platform_setup.intro_link_text'),
          help_center_redirect_path(
            category: 'trouble-signing-in',
            article: 'face-or-touch-unlock',
            flow: :two_factor_authentication,
            step: :webauthn_setup,
          ),
        ),
      )
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

  def device_nickname
    if @platform_authenticator
      recent_devices.first.nice_name
    end
  end

  def button_text
    if @platform_authenticator
      t('forms.webauthn_platform_setup.continue')
    else
      t('forms.webauthn_setup.continue')
    end
  end

  delegate :recent_devices, to: :user
end

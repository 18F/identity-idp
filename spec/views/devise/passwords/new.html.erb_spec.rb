require 'rails_helper'

RSpec.describe 'devise/passwords/new.html.erb' do
  let(:sp) do
    build_stubbed(
      :service_provider,
      friendly_name: 'Awesome Application!',
      return_to_sp_url: 'www.awesomeness.com',
    )
  end
  before do
    @password_reset_email_form = PasswordResetEmailForm.new('')
    view_context = ActionController::Base.new.view_context
    allow(view_context).to receive(:new_user_session_url)
      .and_return('https://www.example.com/')
    allow(view_context).to receive(:sign_up_email_path)
      .and_return('/sign_up/enter_email')
    allow_any_instance_of(ActionController::TestRequest).to receive(:path)
      .and_return('/users/password/new')

    @decorated_sp_session = ServiceProviderSessionCreator.new(
      sp: sp,
      view_context: view_context,
      sp_session: {},
      service_provider_request: ServiceProviderRequestProxy.new,
    ).create_session
    allow(view).to receive(:decorated_sp_session).and_return(@decorated_sp_session)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.passwords.forgot'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.passwords.forgot'))
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'sets input autocorrect to off' do
    render

    expect(rendered).to have_xpath("//input[@autocorrect='off']")
  end

  it 'has a cancel link that points to the decorated_sp_session cancel_link_url' do
    render

    expect(rendered).to have_link(t('links.cancel'), href: @decorated_sp_session.cancel_link_url)
  end

  it 'has sp alert for certain service providers' do
    render

    expect(rendered).to have_selector(
      '.usa-alert',
      text: 'custom forgot password help text for Awesome Application!',
    )
  end

  it 'renders troubleshooting content' do
    render

    expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
    expect(rendered).to have_link(t('forms.passwords.reset.how_to_reset'))
    expect(rendered).to have_link(t('forms.passwords.reset.how_to_reset_with_personal_key'))
  end

  describe 'reCAPTCHA submit button' do
    before do
      allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).and_return(false)
    end

    context 'when password_reset_recaptcha_enabled? is true' do
      before do
        allow(FeatureManagement).to receive(:password_reset_recaptcha_enabled?)
          .and_return(true)
      end

      it 'renders the captcha submit button' do
        render

        expect(rendered).to have_css('lg-captcha-submit-button')
      end
    end

    context 'when password_reset_recaptcha_enabled? is false' do
      before do
        allow(FeatureManagement).to receive(:password_reset_recaptcha_enabled?)
          .and_return(false)
      end

      it 'renders a plain submit button with no captcha' do
        render

        expect(rendered).to have_button(t('forms.buttons.continue'))
        expect(rendered).to_not have_css('lg-captcha-submit-button')
      end

      it 'still renders the captcha when the mock validator is enabled' do
        allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).and_return(true)

        render

        expect(rendered).to have_css('lg-captcha-submit-button')
      end
    end
  end

  context 'service provider does not have custom help text' do
    let(:sp) do
      build_stubbed(
        :service_provider_without_help_text,
        friendly_name: 'Awesome Application!',
        return_to_sp_url: 'www.awesomeness.com',
      )
    end

    it 'does not have an sp alert for service providers without alert messages' do
      render

      expect(rendered).to_not have_selector('.usa-alert--info')
    end
  end
end

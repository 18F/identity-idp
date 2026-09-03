require 'rails_helper'

RSpec.describe 'sign_up/passwords/new.html.erb' do
  let(:user) { build_stubbed(:user) }
  let(:email_address) { user.email_addresses.first }
  let(:forbidden_passwords) { ['password123'] }
  let(:confirmation_token) { 'confirmation-token-abc' }
  let(:nds_layout) { false }
  let(:success_flash) { nil }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:current_user).and_return(nil)
    allow(view).to receive(:params).and_return(confirmation_token: confirmation_token)
    allow(view).to receive(:request_id).and_return(nil)

    flash[:success] = success_flash if success_flash

    @email_address = email_address
    @password_form = PasswordForm.new(user: user)
    @forbidden_passwords = forbidden_passwords
    @confirmation_token = confirmation_token
  end

  it 'sets a shared localized title regardless of layout' do
    expect(view).to receive(:title=).with(t('titles.confirmations.show'))

    render
  end

  context 'in the default (non-NDS) layout' do
    let(:nds_layout) { false }

    before { render }

    it 'renders the legacy heading' do
      expect(rendered).to have_content(t('forms.confirmation.show_hdr'))
    end

    it 'renders the proper Password label' do
      expect(rendered).to have_content(t('forms.password'))
    end

    it 'renders the proper help text' do
      expect(rendered).to have_content strip_tags(
        t('instructions.password.info.lead_html', min_length: Devise.password_length.min),
      )
    end

    it 'includes the user email address as a hidden field' do
      expect(user.email).to be_present
      expect(rendered).to have_css(
        "input[type='text'][name='username'][value='#{user.email}'][autocomplete='username']",
        visible: false,
      )
    end

    it 'includes a form to cancel account creation' do
      expect(rendered).to have_link(t('links.cancel_account_creation'))
    end

    it 'includes platform authenticator available hidden field' do
      expect(rendered).to have_css(
        "input[type='hidden']" \
        "[name='platform_authenticator_available']" \
        "[id='platform_authenticator_available']",
        visible: false,
      )
    end

    it 'does not render the NDS form page card' do
      expect(rendered).not_to have_selector('.auth--form-page')
    end

    it 'does not set the NDS header progress' do
      expect(view.content_for(:nds_header_progress)).to be_blank
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    before { render }

    it 'renders the NDS form page card with the heading and subtitle' do
      expect(rendered).to have_selector('.auth--form-page')
      expect(rendered).to have_selector('h1', text: t('nds.passwords.new.heading'))
      expect(rendered).to have_content(t('nds.passwords.new.info'))
    end

    it 'renders the password and confirmation inputs as enhanced NDS floating inputs' do
      expect(rendered).to have_selector(
        '.usa-input--password input.usa-input__control--floating#password_form_password' \
        '[type="password"]',
      )
      expect(rendered).to have_selector(
        '.usa-input--password input.usa-input__control--floating' \
        '#password_form_password_confirmation[type="password"]',
      )
    end

    it 'gates the fields through the input-validation contract' do
      expect(rendered).to have_selector('.usa-input[data-nds-validation-messages]', minimum: 2)
    end

    it 'provides the mismatch message so unequal passwords gate submission' do
      messages = Capybara.string(rendered).find(
        '#password_form_password_confirmation',
      ).ancestor('.usa-input')['data-nds-validation-messages']

      expect(JSON.parse(messages)).to include(
        'customError' => t('components.password_confirmation.errors.mismatch'),
      )
    end

    it 'renders the NDS password strength meter wired to the password input' do
      expect(rendered).to have_selector(
        "lg-nds-password-strength[input-id='password_form_password']",
        visible: :all,
      )
    end

    it 'loads the password strength custom element pack' do
      expect(view.instance_variable_get(:@scripts)).to include('nds_password_strength_component')
    end

    it 'passes the forbidden passwords and minimum length to the strength meter' do
      expect(rendered).to have_selector(
        "lg-nds-password-strength[forbidden-passwords='#{forbidden_passwords.to_json}']",
        visible: :all,
      )
      expect(rendered).to have_selector(
        "lg-nds-password-strength[minimum-length='#{Devise.password_length.first}']",
        visible: :all,
      )
    end

    it 'posts to the create-password path' do
      expect(rendered).to have_css("form[action='#{sign_up_create_password_path}']")
    end

    it 'preserves the hidden username field' do
      expect(rendered).to have_css(
        "input[name='username'][value='#{user.email}'][autocomplete='username']",
        visible: false,
      )
    end

    it 'preserves the hidden confirmation token field' do
      expect(rendered).to have_field(
        'confirmation_token',
        type: 'hidden',
        with: confirmation_token,
      )
    end

    it 'preserves the platform authenticator hidden field' do
      expect(rendered).to have_css(
        "input[type='hidden'][id='platform_authenticator_available']",
        visible: false,
      )
    end

    it 'renders a Continue submit button' do
      expect(rendered).to have_button(t('forms.buttons.continue'))
    end

    it 'sets the header progress at Account substep 2 of 2' do
      progress = Capybara.string(view.content_for(:nds_header_progress))

      expect(progress).to have_selector('nds-progress .progress__step[aria-current="step"]')
      expect(progress).to have_selector(
        '.progress__step[aria-current="step"] .progress__step-counter',
        text: '2 / 2',
      )
    end

    context 'when a success flash is present' do
      let(:success_flash) { t('devise.confirmations.confirmed_but_must_set_password') }

      it 'renders the confirmation as an NDS toast' do
        expect(rendered).to have_selector('lg-toast', text: success_flash, visible: :all)
      end

      it 'does not render the default flash inside the form page card' do
        expect(rendered).not_to have_selector('.auth--form-page .usa-alert')
      end

      it 'skips the layout flash' do
        expect(view.content_for(:skip_layout_flash)).to be_present
      end
    end
  end
end

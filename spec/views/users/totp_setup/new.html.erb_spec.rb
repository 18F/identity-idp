require 'rails_helper'

RSpec.describe 'users/totp_setup/new.html.erb' do
  let(:user) { create(:user, :fully_registered) }
  let(:nds_layout) { false }
  let(:in_account_creation_flow) { false }
  let(:enabled_mfa_methods_count) { 0 }
  let(:code) { 'D4C2L47CVZ3JJHD7' }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return(signing_up: false)
    allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
    allow(view).to receive(:in_account_creation_flow?).and_return(in_account_creation_flow)
    allow(view).to receive(:enabled_mfa_methods_count).and_return(enabled_mfa_methods_count)

    @code = code
    @qrcode = 'qrcode.png'
    @presenter = SetupPresenter.new(
      current_user: user,
      user_fully_authenticated: false,
      user_opted_remember_device_cookie: true,
      remember_device_default: true,
    )
  end

  it 'sets a shared localized title regardless of layout' do
    expect(view).to receive(:title=).with(t('titles.totp_setup.new'))

    render
  end

  context 'in the default (non-NDS) layout' do
    let(:nds_layout) { false }

    before { render }

    it 'renders the QR code and its image with useful alt text' do
      expect(rendered).to have_css('#qr-code', text: code)

      image_tag = Capybara.string(rendered.html).find_css('img[src^="/images/qrcode.png"]').first
      expect(image_tag).to be
      expect(image_tag['alt']).to eq(t('image_description.totp_qrcode'))
    end

    it 'renders a link to cancel and go back to the account page' do
      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end

    it 'has a button to copy the QR code' do
      expect(rendered).to have_button(t('components.clipboard_button.label'), type: 'button')
    end

    it 'has labelled, aria-labelled fields' do
      expect(rendered).to have_selector(
        'h2#totp-step-1-label',
        text: t('forms.totp_setup.totp_step_1'),
      )
      expect(rendered).to have_selector(
        'h2#totp-step-4-label',
        text: t('forms.totp_setup.totp_step_4'),
      )
      expect(rendered).to have_selector('[aria-labelledby="totp-step-1-label"]')
      expect(rendered).to have_selector('[aria-labelledby="totp-step-4-label"]')
    end

    it 'does not render the NDS form page card' do
      expect(rendered).not_to have_selector('.auth--form-page')
    end

    it 'does not set the NDS header progress' do
      expect(view.content_for(:nds_header_progress)).to be_blank
    end

    context 'user is setting up 2FA' do
      let(:user) { create(:user) }

      before do
        allow(view).to receive(:user_session).and_return(signing_up: true)
        render
      end

      it 'renders a link to choose a different option' do
        expect(rendered).to have_link(
          t('two_factor_authentication.choose_another_option'),
          href: authentication_methods_setup_path,
        )
      end
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    before { render }

    it 'renders the NDS form page card with the heading' do
      expect(rendered).to have_selector('.auth--form-page')
      expect(rendered).to have_selector('h1', text: t('nds.totp_setup.new.heading'))
    end

    it 'renders the QR code, setup code readout, copy button, and manual-entry hint' do
      expect(rendered).to have_css('#qr-code.field-readout__value', text: code)
      expect(rendered).to have_css('img[src^="/images/qrcode.png"]')
      expect(rendered).to have_content(t('nds.totp_setup.new.setup_code_label'))
      expect(rendered).to have_button(t('components.clipboard_button.label'), type: 'button')
      expect(rendered).to have_selector(
        '#totp-manual-entry',
        text: t('instructions.mfa.authenticator.manual_entry'),
      )
    end

    it 'renders the numbered steps as discrete flat cards' do
      expect(rendered).to have_selector(
        '.card.stack--gap-24 ol.usa-list[start="1"] li.text-body-emphasis#totp-step-1-label',
        text: t('nds.totp_setup.new.step_1'),
      )
      expect(rendered).to have_selector(
        '.card.stack--gap-24 ol.usa-list[start="2"] li.text-body-emphasis',
        text: t('nds.totp_setup.new.step_2'),
      )
      expect(rendered).to have_selector(
        '.card.stack--gap-24 ol.usa-list[start="3"] li.text-body-emphasis',
        text: t('nds.totp_setup.new.step_3'),
      )
      expect(rendered).to have_selector(
        '.card.stack--gap-24 ol.usa-list[start="4"] li.text-body-emphasis#totp-step-4-label',
        text: t('forms.totp_setup.totp_step_4'),
      )
      expect(rendered).to have_selector('ol.usa-list--unstyled > li .card.stack--gap-24', count: 4)
      expect(rendered).not_to have_selector('ol.usa-list--unstyled .card .card__inner')
    end

    it 'renders the remember-device checkbox as a plain NDS flat checkbox in a card' do
      expect(rendered).to have_selector(
        '.card .checkbox-group .checkbox input.checkbox__input[name="remember_device"]',
        visible: :all,
      )
      expect(rendered).to have_selector(
        '.checkbox label.checkbox__label .checkbox__label-text',
        text: t('forms.messages.remember_device'),
      )
      expect(rendered).to have_selector(
        '.checkbox__label-description',
        text: strip_tags(t('nds.totp_setup.new.remember_device_info')),
      )
      expect(rendered).not_to have_selector('.checkbox__input--tile')
      expect(rendered).not_to have_selector('.usa-checkbox__input--tile')
      expect(rendered).not_to have_selector('.usa-checkbox__input--bordered')
    end

    it 'gates the submit button on form state' do
      expect(rendered).to have_selector('form[data-nds-submit-gate]')
    end

    it 'renders the setup code as a static readout (not an input) with a bare copy button inside' do
      expect(rendered).to have_selector('.field-readout .field-readout__value#qr-code', text: code)
      expect(rendered).to have_selector(
        '.field-readout .field-readout__label',
        text: t('nds.totp_setup.new.setup_code_label'),
      )
      expect(rendered).not_to have_css('input#qr-code')
      expect(rendered).to have_selector(
        '.field-readout button.field-readout__action[aria-label="' +
                t('components.clipboard_button.label') + '"]',
      )
      expect(rendered).not_to have_selector('.field-readout__action.usa-button')
    end

    it 'renders the code confirmation as a floating-label input labeled Code' do
      expect(rendered).to have_selector(
        'lg-one-time-code-input .usa-input-group--floating input.usa-input#code[name="code"]',
      )
      expect(rendered).to have_selector(
        'label.usa-label[for="code"]',
        text: t('nds.totp_setup.new.code_label'),
      )
      expect(rendered).not_to have_content('Example: 123456')
    end

    it 'renders the nickname field with a visible label' do
      expect(rendered).to have_field(t('nds.totp_setup.new.nickname_label'))
      expect(rendered).to have_css("input[name='name'][maxlength='20']")
      expect(rendered).to have_selector('input#name[aria-labelledby="totp-step-1-label"]')
    end

    it 'submits with a continue button' do
      expect(rendered).to have_button(t('forms.buttons.continue'))
    end

    context 'during sign-in (not account creation)' do
      let(:in_account_creation_flow) { false }

      it 'does not set the NDS header progress' do
        expect(view.content_for(:nds_header_progress)).to be_blank
      end
    end

    context 'during account creation with no methods yet' do
      let(:in_account_creation_flow) { true }
      let(:enabled_mfa_methods_count) { 0 }

      it 'sets the security stepper on the first substep' do
        expect(view.content_for(:nds_header_progress)).to be_present
      end
    end

    context 'during account creation with a method already enabled' do
      let(:in_account_creation_flow) { true }
      let(:enabled_mfa_methods_count) { 1 }

      it 'sets the security stepper' do
        expect(view.content_for(:nds_header_progress)).to be_present
      end
    end

    context 'user already has two-factor enabled' do
      let(:user) { create(:user, :fully_registered) }

      it 'renders a cancel link to the account page' do
        expect(rendered).to have_link(t('links.cancel'), href: account_path)
      end
    end

    context 'user is still setting up their first method' do
      let(:user) { create(:user) }

      it 'renders a link to choose another method' do
        expect(rendered).to have_link(
          t('nds.mfa.choose_another_method'),
          href: authentication_methods_setup_path,
        )
      end
    end
  end
end

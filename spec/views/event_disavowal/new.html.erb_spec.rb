require 'rails_helper'

RSpec.describe 'event_disavowal/new.html.erb' do
  let(:user) { build_stubbed(:user) }
  let(:event) { instance_double(Event, user:) }
  let(:form) { EventDisavowal::PasswordResetFromDisavowalForm.new(event) }
  let(:disavowal_token) { 'disavowal-token' }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:password_reset_from_disavowal_form, form)
    assign(:disavowal_token, disavowal_token)
    assign(:forbidden_passwords, [])
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.passwords.change'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the change password form' do
      expect(rendered).to have_css('h1', text: t('headings.passwords.change'))
      expect(rendered).to have_css("form[action='#{events_disavowal_url}']")
      expect(rendered).to have_css(
        "input[type=hidden][name='disavowal_token'][value='#{disavowal_token}']",
        visible: :all,
      )
      expect(rendered).to have_field(t('forms.passwords.edit.labels.password'), type: 'password')
      expect(rendered).to have_button(t('forms.passwords.edit.buttons.submit'))
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'has a title matching the change password heading' do
      expect(view).to receive(:title=).with(t('headings.passwords.change'))

      render
    end

    it 'renders the form-page card with the heading and intro' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__intro h1', text: t('headings.passwords.change'))
      expect(rendered).to have_css('.auth__intro-description', text: t('nds.passwords.new.info'))
    end

    it 'posts the token and the same password param to the disavowal path' do
      render

      expect(rendered).to have_css(
        "form[action='#{events_disavowal_url}'][method='post'][data-nds-submit-gate]",
      )
      expect(rendered).to have_css(
        "input[type=hidden][name='disavowal_token'][value='#{disavowal_token}']",
        visible: :all,
      )
      expect(rendered).to have_css(
        "input.usa-input__control--password[autocomplete='new-password'][required]" \
          "[name='event_disavowal_password_reset_from_disavowal_form[password]']",
      )
      expect(rendered).to have_field(t('forms.passwords.edit.labels.password'), type: 'password')
    end

    it 'renders the NDS password strength meter for the field' do
      render

      expect(rendered).to have_css(
        "lg-nds-password-strength" \
          "[input-id='event_disavowal_password_reset_from_disavowal_form_password']",
        visible: :all,
      )
    end

    it 'renders the change password submit' do
      render

      expect(rendered).to have_css(
        'button[type=submit]',
        text: t('forms.passwords.edit.buttons.submit'),
      )
    end

    context 'with a password error' do
      let(:message) { t('errors.attributes.password.too_short.other', count: 12) }

      before do
        form.errors.add(:password, message)
      end

      it 'renders the error on the field' do
        render

        expect(rendered).to have_css('.usa-input__error', text: message)
      end
    end
  end
end

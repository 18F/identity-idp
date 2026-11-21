require 'rails_helper'

RSpec.describe 'users/passwords/edit.html.erb' do
  let(:required_password_change) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    user = User.new
    allow(view).to receive(:current_user).and_return(user)
    @update_user_password_form = UpdateUserPasswordForm.new(user: user)
    @update_password_presenter = UpdatePasswordPresenter.new(
      user: user,
      required_password_change: required_password_change,
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.edit_info.password'))

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_content t('headings.edit_info.password')
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'contains minimum password length requirements and warnings' do
    render

    expect(rendered).to have_content strip_tags(
      t(
        'instructions.password.info.lead_html',
        min_length: Devise.password_length.min,
      ),
    )
    expect(rendered).to have_content strip_tags(t('users.edit_info.link'))
    expect(rendered).to have_content strip_tags(t('users.edit_info.warning'))
  end

  it 'has aria described by' do
    render

    expect(rendered).to have_selector('[aria-describedby="password-description"]')
  end

  context 'required password change' do
    let(:required_password_change) { true }

    it 'has alert component content for required password change' do
      render

      expect(rendered).to have_content t('users.password_compromised.warning', app_name: APP_NAME)
    end

    it 'has a submit content for submission page' do
      render

      expect(rendered).to have_content I18n.t('forms.passwords.edit.buttons.submit')
    end

    it 'does not have cancel content for submission page' do
      render
      expect(rendered).to_not have_content(t('links.cancel'))
    end

    describe 'compromised-password alert bucket-conditional rendering' do
      context 'legacy bucket' do
        it 'renders a plain non-dismissible usa-alert, no mount/close' do
          render
          expect(rendered).to have_css(
            '.usa-alert.usa-alert--warning > .usa-alert__body > .usa-alert__text',
          )
          expect(rendered).not_to have_css('lg-alert')
          expect(rendered).not_to have_css('.usa-alert__close')
        end
      end

      context 'nds bucket' do
        before { allow(view).to receive(:nds_layout?).and_return(true) }

        it 'stays non-dismissible: no mount/close button' do
          render
          expect(rendered).to have_css(
            '.usa-alert.usa-alert--warning > .usa-alert__body > .usa-alert__text',
          )
          expect(rendered).not_to have_css('lg-alert')
          expect(rendered).not_to have_css('.usa-alert__close')
        end
      end
    end
  end

  it 'does not render the NDS form page in the default layout' do
    render

    expect(rendered).to_not have_css('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the Figma heading and copy in the signed-in header layout' do
      render

      expect(view.content_for(:nds_account_header)).to eq('true')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('nds.dashboard_account.edit_password_heading'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: "#{t('nds.passwords.new.info')} #{t('users.edit_info.warning')}",
      )
      expect(rendered).to_not have_link(t('users.edit_info.link'))
      expect(rendered).to_not have_content(t('instructions.password.info.lead_html'))
    end

    it 'patches the new password and its confirmation with the NDS strength meter' do
      render

      expect(rendered).to have_css(
        "form[action='#{manage_password_path}'][data-nds-submit-gate] " \
          "input[name='_method'][value=patch]",
        visible: :all,
      )
      expect(rendered).to have_css(
        "input[type=password][name='update_user_password_form[password]']" \
          "[autocomplete=new-password][required]",
      )
      expect(rendered).to have_css(
        "input[type=password][name='update_user_password_form[password_confirmation]']" \
          "[autocomplete=new-password][required]",
      )
      expect(rendered).to have_css('label', text: t('forms.password'))
      expect(rendered).to have_css(
        'label',
        text: t('components.password_confirmation.confirm_label'),
      )
      expect(rendered).to have_css(
        "lg-nds-password-strength[input-id='update_user_password_form_password']",
        visible: :all,
      )
    end

    it 'renders a primary Continue submit above a tertiary Cancel' do
      render

      expect(rendered).to have_css(
        '.auth__actions button[type=submit].usa-button:not(.usa-button--secondary)',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_link(
        t('links.cancel'), href: account_path,
                           class: 'usa-button--tertiary'
      )
    end

    context 'with a password error' do
      before do
        @update_user_password_form.errors.add(
          :password,
          t('errors.messages.too_short.other', count: 12),
        )
      end

      it 'ties the error to the password field' do
        render

        expect(rendered).to have_css(
          "input[name='update_user_password_form[password]'][aria-invalid=true]",
        )
        expect(rendered).to have_content(t('errors.messages.too_short.other', count: 12))
      end
    end

    context 'required password change' do
      let(:required_password_change) { true }

      it 'shows the compromised password warning and no Cancel' do
        render

        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--warning',
          text: t('users.password_compromised.warning', app_name: APP_NAME),
        )
        expect(rendered).to_not have_link(t('links.cancel'))
      end
    end
  end
end

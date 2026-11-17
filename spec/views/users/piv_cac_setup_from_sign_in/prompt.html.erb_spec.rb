require 'rails_helper'

RSpec.describe 'users/piv_cac_setup_from_sign_in/prompt.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.piv_cac_login.add'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the nickname form, the decline button and the cancel link' do
      expect(rendered).to have_css('h1', text: t('titles.piv_cac_login.add'))
      expect(rendered).to have_css("form[action='#{submit_new_piv_cac_url}']")
      expect(rendered).to have_field(t('forms.piv_cac_setup.nickname'))
      expect(rendered).to have_button(t('forms.piv_cac_setup.submit'))
      expect(rendered).to have_css(
        "form[action='#{login_add_piv_cac_prompt_path}'][method='post'] button",
        text: t('forms.piv_cac_setup.no_thanks'),
      )
      expect(rendered).to have_link(t('links.cancel'), href: new_user_session_url)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading and intro' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__intro h1', text: t('titles.piv_cac_login.add'))
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('headings.piv_cac_login.add'),
      )
    end

    it 'renders the three setup steps' do
      render

      expect(rendered).to have_css('.card li', text: t('nds.piv_cac_setup.step_1'))
      expect(rendered).to have_css('.card li', text: t('nds.piv_cac_setup.step_2'))
      expect(rendered).to have_css('.card li', text: t('nds.piv_cac_setup.step_3'))
      expect(rendered).to have_css('.card p', text: t('nds.piv_cac_setup.step_3_info'))
    end

    it 'submits the same name field to the PIV/CAC service' do
      render

      expect(rendered).to have_css(
        "form[action='#{submit_new_piv_cac_url}'][data-nds-submit-gate]",
      )
      expect(rendered).to have_css("input#name[name='name'][required][maxlength='20']")
      expect(rendered).to have_field(t('nds.piv_cac_setup.nickname'))
      expect(rendered).to have_css(
        "form[action='#{submit_new_piv_cac_url}'] button[type=submit]",
        text: t('forms.buttons.continue'),
      )
    end

    it 'renders the decline and cancel actions' do
      render

      expect(rendered).to have_css(
        ".auth__actions form[action='#{login_add_piv_cac_prompt_path}'][method='post'] " \
          "button.usa-button--tertiary",
        text: t('forms.piv_cac_setup.no_thanks'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{new_user_session_url}']",
        text: t('links.cancel'),
      )
    end

    context 'when the user is signing up' do
      before { allow(view).to receive(:user_signing_up?).and_return(true) }

      it 'cancels account creation without the legacy glyph' do
        render

        label = t('links.cancel_account_creation').delete_prefix('‹').strip
        expect(rendered).to have_css(
          ".auth__actions a.usa-button--tertiary[href='#{sign_up_cancel_path}']",
          exact_text: label,
        )
        expect(rendered).not_to have_css('.auth__actions a', text: '‹')
      end
    end
  end
end

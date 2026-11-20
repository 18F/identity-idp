require 'rails_helper'

RSpec.describe 'users/webauthn_setup_mismatch/show.html.erb' do
  subject(:rendered) { render }
  let(:configuration) { create(:webauthn_configuration) }
  let(:presenter) { WebauthnSetupMismatchPresenter.new(configuration:) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:presenter, presenter)
  end

  it 'sets title from presenter heading' do
    expect(view).to receive(:title=).with(presenter.heading)

    render
  end

  it 'renders heading from presenter heading' do
    expect(rendered).to have_css('h1', text: presenter.heading)
  end

  it 'renders description from presenter description' do
    expect(rendered).to have_css('p', text: presenter.description)
  end

  it 'renders buttons to continue or undo' do
    expect(rendered).to have_button(t('forms.buttons.continue'))
    expect(rendered).to have_button(t('webauthn_setup_mismatch.undo'))
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).not_to have_css('.auth--form-page')
  end

  context 'in the NDS layout' do
    before { allow(view).to receive(:nds_layout?).and_return(true) }

    it 'renders the presenter heading under a warning status icon and divider' do
      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon--warning .usa-icon')
      expect(rendered).to have_css('.auth--form-page h1', text: presenter.heading)
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__form-page-body > hr.divider')
      expect(rendered).not_to have_css('img')
    end

    it 'renders the description and the undo explanation' do
      expect(rendered).to have_css(
        '.auth__form-page-body .copy--muted p',
        text: presenter.description,
      )
      expect(rendered).to have_css(
        '.auth__form-page-body .copy--muted p',
        text: t('webauthn_setup_mismatch.description_undo'),
      )
    end

    it 'renders a primary continue (PATCH) above a tertiary undo (DELETE)' do
      expect(rendered).to have_css(
        ".auth__actions form[action='#{webauthn_setup_mismatch_url}']" \
        ":has(input[name=_method][value=patch]) button.usa-button:not(.usa-button--tertiary)",
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_css(
        ".auth__actions form[action='#{webauthn_setup_mismatch_url}']" \
        ":has(input[name=_method][value=delete]) button.usa-button--tertiary",
        text: t('webauthn_setup_mismatch.undo'),
      )
      expect(rendered.index(t('forms.buttons.continue')))
        .to be < rendered.index(t('webauthn_setup_mismatch.undo'))
    end

    context 'when the new configuration is a platform authenticator' do
      let(:configuration) { create(:webauthn_configuration, platform_authenticator: true) }

      it 'renders the passkey heading' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('webauthn_setup_mismatch.heading.webauthn_platform'),
        )
      end
    end
  end
end

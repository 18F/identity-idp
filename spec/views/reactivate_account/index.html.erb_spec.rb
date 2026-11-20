require 'rails_helper'

RSpec.describe 'reactivate_account/index.html.erb' do
  subject(:rendered) do
    render
  end

  let(:personal_key_generated_at) { Time.zone.parse('2020-04-09T14:03:00Z').utc }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:personal_key_generated_at, personal_key_generated_at)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.reactivate_account'))

    render
  end

  context 'in the default layout' do
    it 'displays a fallback warning alert when js is off' do
      expect(rendered).to have_content(t('instructions.account.reactivate.modal.copy'))
    end

    it 'displays the date the personal key was generated without time' do
      expect(rendered).to have_content('April 9, 2020')
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'has a title matching the personal key question heading' do
      expect(view).to receive(:title=).with(t('instructions.account.reactivate.with_key'))

      render
    end

    it 'renders the form-page card with the personal key question and intro' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('instructions.account.reactivate.with_key'),
      )
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.reactivate_account.info'),
      )
    end

    it 'links to personal key entry and submits the no-key choice to reactivate' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{verify_personal_key_path}']",
        text: t('links.account.reactivate.with_key'),
      )
      expect(rendered).to have_css(
        ".auth__actions form[action='#{reactivate_account_path}'] " \
        "input[name='_method'][value='put']",
        visible: :all,
      )
      expect(rendered).to have_css(
        '.auth__actions button#no-key-reactivate.usa-button--secondary' \
        '[data-nds-modal-open][aria-controls="reactivate-account-modal"]',
        text: t('links.account.reactivate.without_key'),
      )
    end

    it 'renders the no-js warning alert' do
      expect(rendered).to have_css(
        '.auth--form-page .no-js .usa-alert--warning',
        text: t('instructions.account.reactivate.modal.copy'),
      )
    end

    it 'renders the confirmation modal with continue and cancel' do
      expect(rendered).to have_css(
        'lg-modal dialog.modal.reactivate-account-modal#reactivate-account-modal',
        visible: :all,
      )
      expect(rendered).to have_css(
        'lg-modal .modal__title',
        text: t('instructions.account.reactivate.modal.heading'),
        visible: :all,
      )
      expect(rendered).to have_css(
        'lg-modal .modal__description',
        text: t('instructions.account.reactivate.modal.copy'),
        visible: :all,
      )
      expect(rendered).to have_css(
        "lg-modal form[action='#{reactivate_account_path}'] button[name='personal_key']",
        text: t('forms.buttons.continue'),
        visible: :all,
      )
      expect(rendered).to have_css(
        'lg-modal button[data-dismiss]',
        text: t('links.cancel'),
        visible: :all,
      )
    end

    it 'does not render the legacy key preview' do
      expect(rendered).to_not have_content(t('headings.account.reactivate'))
      expect(rendered).to_not have_css('.personal-key-block')
    end
  end
end

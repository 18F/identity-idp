require 'rails_helper'

RSpec.describe 'sign_up/cancellations/new.html.erb' do
  let(:go_back_path) { '/authentication_methods_setup' }
  let(:presenter) { instance_double(CancellationPresenter, go_back_path:) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:presenter, presenter)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('headings.cancellations.prompt'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the consequences and both actions' do
      expect(rendered).to have_css('h1', text: t('headings.cancellations.prompt'))
      expect(rendered).to have_css('ul.usa-list li', count: 4)
      expect(rendered).to have_css(
        "form[action='#{sign_up_destroy_path}'] input[name='_method'][value='delete']",
        visible: :all,
      )
      expect(rendered).to have_button(t('forms.buttons.cancel'))
      expect(rendered).to have_link(t('links.go_back'), href: go_back_path)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page card with the warning badge and heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--warning')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__intro h1', text: t('headings.cancellations.prompt'))
    end

    it 'renders the divider and the four consequences' do
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css(
        '.auth__form-page-body p strong',
        text: t('sign_up.cancel.warning_header'),
      )
      expect(rendered).to have_css('.auth__form-page-body ul.usa-list li', count: 4)
      expect(rendered).to have_css(
        '.auth__form-page-body li',
        text: t('users.delete.bullet_2_basic'),
      )
    end

    it 'renders a primary cancel action that deletes the account' do
      expect(rendered).to have_css(
        ".auth__actions form[action='#{sign_up_destroy_path}'] " \
          "input[name='_method'][value='delete']",
        visible: :all,
      )
      expect(rendered).to have_css(
        ".auth__actions form[action='#{sign_up_destroy_path}'] button.usa-button",
        text: t('forms.buttons.cancel'),
      )
    end

    it 'renders a tertiary go back action' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{go_back_path}']",
        text: t('links.go_back'),
      )
    end

    it 'renders the actions in legacy order' do
      expect(rendered.index(t('forms.buttons.cancel')))
        .to be < rendered.index(t('links.go_back'))
    end
  end
end

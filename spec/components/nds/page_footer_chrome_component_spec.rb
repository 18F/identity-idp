require 'rails_helper'

RSpec.describe NDS::PageFooterChromeComponent, type: :component do
  before do
    allow_any_instance_of(BaseComponent).to receive(:nds_bucket?).and_return(true)
    # A few redirect-url helpers are the only external deps; stub them so the
    # component renders in isolation. The real ViewComponent test request
    # supplies request.fullpath/base_url.
    allow_any_instance_of(NDS::PageFooterChromeComponent).to receive_message_chain(
      :helpers, :contact_redirect_url
    ).and_return('/contact')
    allow_any_instance_of(NDS::PageFooterChromeComponent).to receive_message_chain(
      :helpers, :help_center_redirect_url
    ).and_return('/help')

    # This prevents the component from raising an error due to missing CSRF protection in the
    # test environment.
    allow_any_instance_of(NDS::PageFooterChromeComponent).to receive_message_chain(
      :helpers, :protect_against_forgery?
    ).and_return(false)
  end

  subject(:rendered) { render_inline(NDS::PageFooterChromeComponent.new) }

  it 'renders the unprefixed page-footer custom element + footer' do
    expect(rendered).to have_css('lg-nds-page-footer > footer.page-footer')
  end

  it 'renders the agency identifier with unprefixed classes' do
    expect(rendered).to have_css('.page-footer__agency .page-footer__agency-name')
  end

  it 'renders a localized experience notice with a same-page legacy link' do
    expect(rendered).to have_css(
      'aside.page-footer__experience-notice p.copy.copy--muted',
      text: t('nds.footer.experience_notice_link'),
    )
    expect(rendered).to have_link(
      t('nds.footer.experience_notice_link'),
      href: NDS::PageFooterChromeComponent::NEW_USER_INTERFACE_URL,
      class: 'usa-link link--nowrap',
    )
    expect(rendered).to have_button(
      t('nds.footer.switch_to_legacy'),
    )
    expect(rendered).to have_css(
      "form[action='/nds/opt_out'][method='post']",
    )
  end

  it 'renders language + overflow menus as native details popover-menus' do
    expect(rendered).to have_css('details.page-footer__menu', count: 2)
    expect(rendered).to have_css(
      'details.page-footer__menu > summary.usa-button.usa-button--quaternary',
      count: 2,
    )
    expect(rendered).to have_css(
      '.popover-menu .popover-menu__item[lang="en"]', text: 'English', visible: :all
    )
    expect(rendered).to have_css('.popover-menu .popover-menu__item[lang="es"]', visible: :all)
  end

  it 'renders the privacy and help links as quaternary footer buttons' do
    expect(rendered).to have_css(
      'a.usa-button.usa-button--quaternary', text: t('links.privacy_policy')
    )
    expect(rendered).to have_css(
      'a.page-footer__help.usa-button.usa-button--quaternary', text: t('links.help')
    )
  end

  it 'does not render legacy native select controls' do
    expect(rendered).not_to have_css('select.page-footer__select')
  end
end

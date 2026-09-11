require 'rails_helper'

RSpec.describe NDS::AuthEntryComponent, type: :component do
  it 'renders the auth-entry scaffold with blurs, marketing aside, and card content' do
    rendered = render_inline(NDS::AuthEntryComponent.new) { 'CARD BODY' }

    expect(rendered).to have_css('.auth-entry')
    expect(rendered).to have_css('.auth-entry__blurs[aria-hidden] .auth-entry__blurs-image')
    expect(rendered).to have_css(
      '.auth-entry__marketing .auth-entry__whats-new .auth-entry__whats-new-intro',
    )
    expect(rendered).to have_css(
      '.auth-entry__marketing .auth-entry__whats-new-link',
      text: t('auth_entry.whats_new_link'),
    )
    expect(rendered).to have_css('.auth-entry__logo .auth-entry__logo-image')
    expect(rendered).to have_css(
      '.auth-entry__copy .auth-entry__headline',
      text: t('auth_entry.headline'),
    )
    expect(rendered).to have_css('.auth-entry__copy .auth-entry__body', text: t('auth_entry.body'))
    expect(rendered).to have_css('.auth-entry__card', text: 'CARD BODY')
  end

  it 'emits no prefixed ads- classes' do
    rendered = render_inline(NDS::AuthEntryComponent.new) { 'x' }
    expect(rendered.to_html).not_to include('ads-')
  end
end

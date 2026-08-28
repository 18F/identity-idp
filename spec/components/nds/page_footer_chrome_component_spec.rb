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
  end

  subject(:rendered) { render_inline(NDS::PageFooterChromeComponent.new) }

  it 'renders the unprefixed page-footer custom element + footer' do
    expect(rendered).to have_css('lg-nds-page-footer > footer.page-footer')
  end

  it 'renders the agency link with unprefixed classes' do
    expect(rendered).to have_css('a.page-footer__agency .page-footer__agency-name')
  end

  it 'renders language + destination select controls with unprefixed classes' do
    expect(rendered).to have_css('select.page-footer__select[name="locale"]')
    expect(rendered).to have_css('select.page-footer__select[name="footer_destination"]')
    expect(rendered).to have_css('.page-footer__control', count: 2)
    html = rendered.to_html
    expect(html).to include('footer-language-')
    expect(html).to include('footer-destination-')
  end
end

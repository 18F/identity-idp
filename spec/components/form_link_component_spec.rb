require 'rails_helper'

RSpec.describe FormLinkComponent, type: :component do
  let(:options) { { href: '/', method: :post } }
  let(:content) { 'Link' }

  subject(:rendered) do
    render_inline described_class.new(**options).with_content(content)
  end

  it 'renders custom element with link and form' do
    expect(rendered).to have_css('lg-form-link a[href="/"]', text: content)
    expect(rendered).to have_css('lg-form-link form.display-none[method="post"][action="/"]')
  end
end

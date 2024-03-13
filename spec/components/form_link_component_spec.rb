require 'rails_helper'

RSpec.describe FormLinkComponent, type: :component do
  let(:options) { { href: '/', method: :post } }
  let(:content) { 'Title' }

  subject(:rendered) do
    render_inline(described_class.new(**options).with_content(content))
  end

  it 'renders custom element with link' do
    expect(rendered).to have_css('lg-form-link a[href="/"]', text: content)
  end
end

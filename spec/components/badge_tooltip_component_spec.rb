require 'rails_helper'

RSpec.describe BadgeTooltipComponent, type: :component do
  let(:tooltip_text) { 'Your identity has been verified.' }
  let(:content) { 'Verified' }
  let(:icon) { :check_circle }
  let(:options) { { icon: :check_circle } }

  subject(:rendered) do
    render_inline BadgeTooltipComponent.new(tooltip_text:, icon:, **options).with_content(content)
  end

  it 'renders badge as tooltip, with content and tooltip text' do
    expect(rendered).to have_css(
      ".badge-tooltip .lg-verification-badge[title='#{tooltip_text}'].usa-tooltip",
      text: content,
    )
  end

  context 'with additional tag options' do
    let(:options) { super().merge(data: { foo: 'bar' }) }

    it 'renders tag options on root wrapper element' do
      expect(rendered).to have_css('.badge-tooltip[data-foo="bar"]')
    end
  end
end

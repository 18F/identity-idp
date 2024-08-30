require 'rails_helper'

RSpec.describe TooltipComponent, type: :component do
  let(:tooltip_text) { 'Your identity has been verified.' }
  let(:options) { {} }
  let(:content) { 'Verified' }

  subject(:rendered) do
    render_inline TooltipComponent.new(tooltip_text:, **options).with_content(content)
  end

  it 'renders badge as tooltip, with content and tooltip text' do
    expect(rendered).to have_css("lg-tooltip[tooltip-text='#{tooltip_text}']", text: content)
  end

  context 'with additional tag options' do
    let(:options) { super().merge(data: { foo: 'bar' }) }

    it 'renders tag options on root wrapper element' do
      expect(rendered).to have_css('lg-tooltip[data-foo="bar"]')
    end
  end
end

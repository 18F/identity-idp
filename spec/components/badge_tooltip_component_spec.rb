require 'rails_helper'

RSpec.describe BadgeTooltipComponent, type: :component do
  let(:tooltip_text) { 'Your identity has been verified.' }
  let(:content) { 'Verified' }
  let(:tag_options) { { icon: :check_circle } }

  subject(:rendered) do
    render_inline BadgeTooltipComponent.new(tooltip_text:, **tag_options).with_content(content)
  end

  it 'renders with tooltip text as an attribute' do
    expect(rendered).to have_css("lg-badge-tooltip[tooltip-text='#{tooltip_text}']")
  end

  it 'renders badge with content as tooltip' do
    expect(rendered).to have_css('.lg-verification-badge.usa-tooltip', text: content)
  end
end

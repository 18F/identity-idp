require 'rails_helper'

RSpec.describe BadgeTooltipComponent, type: :component do
  let(:tooltip_text) { 'Your identity has been verified.' }
  let(:tag_options) { { icon: :check_circle } }

  subject(:rendered) do
    render_inline BadgeTooltipComponent.new(tooltip_text:, **tag_options).with_content(tooltip_text)
  end

  it 'renders with tooltip text as an attribute' do
    expect(rendered).to have_css("lg-badge-tooltip[tooltip-text='#{tooltip_text}']")
  end
end

require 'rails_helper'

RSpec.describe NDS::IconComponent, type: :component do
  it 'renders an inline svg with the usa-icon class at the requested pixel size' do
    rendered = render_inline(NDS::IconComponent.new(icon: :authority, size: 24))

    expect(rendered).to have_css('svg.usa-icon[width="24"][height="24"]')
    expect(rendered).to have_css('svg[aria-hidden="true"]')
  end

  it 'sets role/aria-label when a label is given' do
    rendered = render_inline(NDS::IconComponent.new(icon: :lock, size: 24, label: 'Secure'))

    expect(rendered).to have_css('svg.usa-icon[role="img"][aria-label="Secure"]')
  end

  it 'resolves the official-banner icons' do
    expect(render_inline(NDS::IconComponent.new(icon: :flag_20, size: 20)))
      .to have_css('svg.usa-icon')
    expect(render_inline(NDS::IconComponent.new(icon: :authority, size: 24)))
      .to have_css('svg.usa-icon')
    expect(render_inline(NDS::IconComponent.new(icon: :lock, size: 24)))
      .to have_css('svg.usa-icon')
  end

  it 'validates the icon is in the nds registry' do
    expect { render_inline(NDS::IconComponent.new(icon: :not_a_real_icon)) }
      .to raise_error(ActiveModel::ValidationError)
  end

  it 'validates the size is available for the icon' do
    expect { render_inline(NDS::IconComponent.new(icon: :flag_20, size: 99)) }
      .to raise_error(ActiveModel::ValidationError)
  end

  it 'emits no prefixed ads- classes' do
    rendered = render_inline(NDS::IconComponent.new(icon: :authority, size: 24))
    expect(rendered.to_html).not_to include('ads-')
  end
end

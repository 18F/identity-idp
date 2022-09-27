require 'rails_helper'

RSpec.describe AlertIconComponent, type: :component do
  it 'renders a warning 88x88 by default' do
    rendered = render_inline(described_class.new)
    expect(rendered).to have_css('img')
    expect(rendered).to have_css('.alert-icon')
    expect(rendered).to have_css("[alt='#{t('image_description.warning')}']")
    expect(rendered).to have_css('[width="88"][height="88"]')
  end

  it 'renders the alert-icon class after any custom provided classes' do
    rendered = render_inline(
      described_class.new(
        icon_name: :warning,
        class: 'first-class second-class',
      ),
    )
    expect(rendered).to have_css('[class="first-class second-class alert-icon"]')
  end

  it 'renders a custom alt, if provided' do
    rendered = render_inline(described_class.new(icon_name: :warning, alt: 'custom alt text'))
    expect(rendered).to have_css('[alt="custom alt text"]')
  end

  it 'raises an ArgumentError if an invalid icon name is given' do
    expect { described_class.new(icon_name: :invalid_icon_name) }.to raise_error(ArgumentError)
  end

  it 'renders with the explicitly passed in width and height values' do
    rendered = render_inline(described_class.new(width: 10, height: 20))
    expect(rendered).to have_css('[width="10"][height="20"]')
  end
end

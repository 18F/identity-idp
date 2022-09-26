require 'rails_helper'

RSpec.describe AlertIconComponent, type: :component do
  let(:icon_name) { nil }
  let(:tag_options) { {} }

  subject(:rendered) do
    render_inline(described_class.new)
  end

  it 'renders a warning 88x88 by default' do
    expect(rendered).to have_css('.alert-icon')
    expect(rendered).to have_css("[alt='#{t('image_description.warning')}']")
    expect(rendered).to have_css('[width="88"][height="88"]')
  end

  it 'renders the alert-icon class after any custom provided classes' do
    rendered = render_inline(described_class.new(:warning, class: 'first-class second-class'))
    expect(rendered).to have_css('[class="first-class second-class alert-icon"]')
  end

  it 'renders a custom alt, if provided' do
    rendered = render_inline(described_class.new(:warning, alt: 'custom alt text'))
    expect(rendered).to have_css('[alt="custom alt text"]')
  end

  it 'raises an ArgumentError if an invalid icon name is given' do
    expect { described_class.new(:invalid_icon_name)}.to raise_error(ArgumentError)
  end
end

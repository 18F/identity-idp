require 'rails_helper'

RSpec.describe IconComponent, type: :component do
  let(:icon_root) { described_class::ICON_ROOT }

  it 'builds the registry from on-disk SVG assets' do
    expect(described_class::REGISTRY.size).to eq(127)
    expect(described_class::REGISTRY.values.sum(&:size)).to eq(378)
    expect(described_class::REGISTRY[:flag_20].keys).to eq([20])
    expect(described_class::REGISTRY[:us_flag].keys).to eq([24, 40])
    expect(described_class::REGISTRY.except(:flag_20, :us_flag).values.map(&:keys).uniq)
      .to eq([[16, 20, 24]])
  end

  it 'keeps registry paths in sync with individual SVG files' do
    registered = described_class::REGISTRY.values.flat_map(&:values)
    on_disk = Dir[icon_root.join('**/*.svg')].map do |path|
      Pathname(path).relative_path_from(described_class::ASSET_ROOT).to_s
    end

    expect(on_disk).to match_array(registered)
  end

  it 'keeps monochrome status icons themeable' do
    fills = %i[error error_filled progress_25 download_backup].flat_map do |icon|
      described_class::REGISTRY.fetch(icon).values.flat_map do |asset_path|
        described_class::ASSET_ROOT.join(asset_path)
          .read
          .scan(/\b(?:fill|stroke)="([^"]+)"/)
          .flatten
      end
    end

    expect(fills - %w[none white #E0E0E0]).to all(eq('currentColor'))
  end

  it 'preserves fixed colors for the 20px Flag exception' do
    flag = described_class::ASSET_ROOT.join(described_class::REGISTRY.dig(:flag_20, 20)).read
    fills = flag.scan(/\bfill="([^"]+)"/).flatten.uniq - ['none']

    expect(fills).to contain_exactly('#004AC3', '#D80007')
  end

  it 'is decorative by default' do
    rendered = render_inline described_class.new(icon: :star_filled)

    expect(rendered.at_css('svg')['aria-hidden']).to eq('true')
    expect(rendered).to have_no_css('svg[role="img"]')
    expect(rendered).to have_no_css('svg[aria-label]')
  end

  it 'supports an accessible name for meaningful icons' do
    rendered = render_inline described_class.new(icon: :info, label: 'More information')

    expect(rendered).to have_css('svg[role="img"][aria-label="More information"]')
    expect(rendered).to have_no_css('svg[aria-hidden]')
  end

  it 'rejects icons outside the registry' do
    expect do
      render_inline described_class.new(icon: :unknown)
    end.to raise_error(ActiveModel::ValidationError)
  end

  it 'rejects sizes not available for the selected icon' do
    expect do
      render_inline described_class.new(icon: :flag_20, size: 16)
    end.to raise_error(ActiveModel::ValidationError)

    expect do
      render_inline described_class.new(icon: :us_flag, size: 20)
    end.to raise_error(ActiveModel::ValidationError)
  end

  it 'renders the selected individual SVG inline' do
    rendered = render_inline described_class.new(icon: :error, size: 20)

    expect(rendered).to have_css('svg.ads-icon path')
    expect(rendered.at_css('svg')['viewBox']).to eq('0 0 20 20')
    expect(rendered.at_css('svg')['fill']).to eq('none')
    expect(rendered).to have_no_css('svg use, svg image')
  end
end

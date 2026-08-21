require 'rails_helper'

RSpec.describe BadgeComponent, type: :component do
  let(:icon) {}
  let(:content) { 'Content' }
  let(:options) { { icon: } }

  subject(:rendered) do
    render_inline BadgeComponent.new(**options).with_content(content)
  end

  context 'without icon' do
    let(:icon) { nil }

    it { expect { rendered }.to raise_error(ActiveModel::ValidationError) }
  end

  context 'with invalid icon' do
    let(:icon) { :invalid }

    it { expect { rendered }.to raise_error(ActiveModel::ValidationError) }
  end

  context 'with valid icon' do
    let(:icon) { :check_circle }

    it 'renders badge with icon and content' do
      expect(rendered).to have_css('.lg-verification-badge .usa-icon')
      inline_icon_style = rendered.at_css('.usa-icon style').text.strip
      expect(inline_icon_style).to match(%r{url\([^)]+?/check_circle-\w+\.svg\)})
    end

    context 'with extra tag options' do
      let(:options) { super().merge(class: 'example-class', data: { foo: 'bar' }) }

      it 'renders badge with extra tag options on wrapper element' do
        expect(rendered).to have_css('.lg-verification-badge.example-class[data-foo="bar"]')
      end
    end

    context 'with lock icon' do
      let(:icon) { :lock }

      it 'renders with success color' do
        expect(rendered).to have_css('.lg-verification-badge.border-success .usa-icon.text-success')
      end
    end

    context 'with check_circle icon' do
      let(:icon) { :check_circle }

      it 'renders with success color' do
        expect(rendered).to have_css('.lg-verification-badge.border-success .usa-icon.text-success')
      end
    end

    context 'with warning icon' do
      let(:icon) { :warning }

      it 'renders with warning color' do
        expect(rendered).to have_css('.lg-verification-badge.border-warning .usa-icon.text-warning')
      end
    end

    context 'with info icon' do
      let(:icon) { :info }

      it 'renders with info color' do
        expect(rendered).to have_css('.lg-verification-badge.border-info .usa-icon.text-info')
      end
    end
  end

  # Safety invariant: in the legacy bucket, adding variant:/on_background:
  # must not change the emitted output, and the icon stays required/validated.
  describe 'legacy bucket ignores variant/on_background kwargs' do
    before do
      allow_any_instance_of(BadgeComponent).to receive(:nds_bucket?).and_return(false)
    end

    def html(**opts)
      raw = render_inline(BadgeComponent.new(icon: :check_circle, **opts).with_content('C')).to_html
      # IconComponent assigns a random per-render id; normalize it so the
      # comparison reflects only structural/class differences.
      raw.gsub(/icon-[0-9a-f]+/, 'icon-XXXX')
    end

    it 'renders identical output whether or not variant/on_background are passed' do
      baseline = html
      %i[primary secondary tertiary success error warning info].each do |variant|
        expect(html(variant:)).to eq(baseline)
      end
      expect(html(on_background: :dark)).to eq(baseline)
      expect(html(variant: :success, on_background: :dark)).to eq(baseline)
    end

    it 'renders the legacy div.lg-verification-badge structure' do
      rendered = render_inline(
        BadgeComponent.new(icon: :lock, variant: :error).with_content('X'),
      )
      expect(rendered).to have_css(
        'div.lg-verification-badge.border-success > .usa-icon.text-success',
      )
      expect(rendered).not_to have_css('span.badge')
      expect(rendered).not_to have_css('.badge--error')
    end

    it 'still requires an icon' do
      expect { render_inline(BadgeComponent.new(variant: :primary).with_content('x')) }
        .to raise_error(ActiveModel::ValidationError)
    end

    it 'still validates the icon against the allowed list' do
      expect { render_inline(BadgeComponent.new(icon: :invalid).with_content('x')) }
        .to raise_error(ActiveModel::ValidationError)
    end
  end

  describe 'nds bucket' do
    before do
      allow_any_instance_of(BadgeComponent).to receive(:nds_bucket?).and_return(true)
    end

    it 'renders a span.badge with the variant + content, dropping the icon when content present' do
      rendered = render_inline(
        BadgeComponent.new(icon: :check_circle, variant: :success).with_content('Verified'),
      )
      expect(rendered).to have_css('span.badge.badge--success')
      expect(rendered).to have_content('Verified')
      expect(rendered).not_to have_css('span.badge .usa-icon')
      expect(rendered).not_to have_css('.lg-verification-badge')
    end

    it 'defaults to badge--primary' do
      expect(render_inline(BadgeComponent.new(icon: :info).with_content('x')))
        .to have_css('span.badge.badge--primary')
    end

    {
      primary: 'badge--primary',
      secondary: 'badge--secondary',
      tertiary: 'badge--tertiary',
      success: 'badge--success',
      error: 'badge--error',
      warning: 'badge--warning',
      info: 'badge--info',
    }.each do |variant, modifier|
      it "maps variant #{variant} to .#{modifier}" do
        expect(render_inline(BadgeComponent.new(icon: :info, variant:).with_content('x')))
          .to have_css("span.badge.#{modifier}")
      end
    end

    it 'adds badge--icon-only when icon present and no content' do
      rendered = render_inline(BadgeComponent.new(icon: :lock))
      expect(rendered).to have_css('span.badge.badge--icon-only .usa-icon')
    end

    it 'does not emit an on-light/on-dark modifier' do
      rendered = render_inline(
        BadgeComponent.new(icon: :info, on_background: :dark).with_content('x'),
      )
      expect(rendered).not_to have_css('[class*="on-light"], [class*="on-dark"]')
    end

    it 'renders without an icon (icon optional in nds)' do
      rendered = render_inline(BadgeComponent.new(variant: :secondary).with_content('No icon'))
      expect(rendered).to have_css('span.badge.badge--secondary')
      expect(rendered).to have_content('No icon')
      expect(rendered).not_to have_css('.usa-icon')
    end

    it 'raises on an unknown variant (fetch guards the map)' do
      expect do
        render_inline(BadgeComponent.new(icon: :info, variant: :bogus).with_content('x'))
      end.to raise_error(KeyError)
    end
  end
end

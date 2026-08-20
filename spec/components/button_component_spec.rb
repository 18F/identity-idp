require 'rails_helper'

RSpec.describe ButtonComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::TagHelper

  let(:options) { {} }
  let(:content) { 'Button' }

  subject(:rendered) do
    render_inline ButtonComponent.new(**options).with_content(content)
  end

  it 'renders button content' do
    expect(rendered).to have_content(content)
  end

  it 'renders with design system classes' do
    expect(rendered).to have_css('button.usa-button')
  end

  context 'with outline' do
    let(:options) { { outline: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--outline')
    end
  end

  context 'as big' do
    let(:options) { { big: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--big')
    end
  end

  context 'as wide' do
    let(:options) { { wide: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--wide')
    end
  end

  context 'as full width' do
    let(:options) { { full_width: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--full-width')
    end
  end

  context 'as unstyled' do
    let(:options) { { unstyled: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--unstyled')
    end
  end

  context 'as dangerous' do
    let(:options) { { danger: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--danger')
    end
  end

  context 'with tag options' do
    it 'renders as attributes' do
      rendered = render_inline ButtonComponent.new(
        type: :button,
        class: 'my-custom-class',
        data: { foo: 'bar' },
      )

      expect(rendered).to have_css('.usa-button.my-custom-class[type="button"][data-foo="bar"]')
    end
  end

  context 'with icon' do
    it 'renders an icon' do
      rendered = render_inline ButtonComponent.new(icon: :print).with_content(content)

      expect(rendered).to have_xpath('//style[contains(text(), "/print-")]')
      expect(rendered.first_element_child.xpath('./text()').text).to eq(content)
    end

    context 'with content including whitespace and safe html' do
      let(:content) { safe_join([" \n ", content_tag('span', 'Button', class: 'example')]) }

      it 'trims text of the content, maintaining html safety' do
        rendered = render_inline ButtonComponent.new(icon: :print).with_content(content)

        expect(rendered.to_html).to include('</span><span class="example">Button</span>')
      end
    end

    context 'with content including whitespace and unsafe html' do
      let(:content) { safe_join([" \n ", '<span class="example">Button</span>']) }

      it 'trims text of the content, maintaining html safety' do
        rendered = render_inline ButtonComponent.new(icon: :print).with_content(content)

        expect(rendered.to_html).to include(
          '</span>&lt;span class="example"&gt;Button&lt;/span&gt;',
        )
      end
    end

    context 'with no content' do
      it 'renders without error' do
        render_inline ButtonComponent.new(icon: :print)
      end
    end
  end

  context 'with url' do
    let(:url) { '/' }
    let(:options) { { url: } }

    it 'renders link to url' do
      expect(rendered).to have_link(content, href: url)
    end

    context 'with method' do
      let(:method) { :put }
      let(:options) { super().merge(method:) }

      it 'renders button to url' do
        expect(rendered).to have_selector("form[action='#{url}']")
        expect(rendered).to have_selector("input[name='_method'][value='#{method}']", visible: :all)
        expect(rendered).to have_selector("button[type='submit']")
        expect(rendered).to have_text(content)
      end

      context 'with get method' do
        let(:method) { :get }

        it 'renders link to url' do
          expect(rendered).to have_link(content, href: url)
        end
      end
    end
  end

  # Pattern-setter proof: the component is bucket-conditional. The legacy
  # bucket honors the boolean API and emits origin/main classes (ignoring
  # variant:/size:); the NDS bucket honors variant:/size: and emits the
  # canonical .usa-button--<variant>/--<size> modifiers Path 4 styles.
  describe 'bucket-conditional rendering' do
    describe 'legacy bucket (nds_bucket? false)' do
      before do
        allow_any_instance_of(ButtonComponent).to receive(:nds_bucket?).and_return(false)
      end

      it 'ignores variant:/size: and emits only base .usa-button' do
        rendered = render_inline(
          ButtonComponent.new(variant: :quaternary, size: :sm).with_content('x'),
        )
        expect(rendered).to have_css('button.usa-button')
        expect(rendered).not_to have_css('.usa-button--quaternary')
        expect(rendered).not_to have_css('.usa-button--sm')
      end

      it 'honors the boolean API (origin/main classes)' do
        rendered = render_inline(
          ButtonComponent.new(big: true, outline: true, variant: :quaternary)
            .with_content('x'),
        )
        expect(rendered).to have_css('button.usa-button.usa-button--big.usa-button--outline')
        expect(rendered).not_to have_css('.usa-button--quaternary')
      end
    end

    describe 'nds bucket (nds_bucket? true)' do
      before do
        allow_any_instance_of(ButtonComponent).to receive(:nds_bucket?).and_return(true)
      end

      {
        primary: nil,
        secondary: 'usa-button--secondary',
        tertiary: 'usa-button--tertiary',
        quaternary: 'usa-button--quaternary',
        ghost: 'usa-button--ghost',
        destructive: 'usa-button--danger',
      }.each do |variant, modifier|
        it "maps variant #{variant} to #{modifier || 'base .usa-button'}" do
          rendered = render_inline(
            ButtonComponent.new(variant:, size: :md).with_content('x'),
          )
          expect(rendered).to have_css('button.usa-button')
          expect(rendered).to have_css('.usa-button--md')
          if modifier
            expect(rendered).to have_css(".#{modifier}")
          else
            expect(rendered).not_to have_css(
              '.usa-button--secondary, .usa-button--tertiary, ' \
              '.usa-button--quaternary, .usa-button--ghost',
            )
          end
        end
      end

      it 'maps sizes lg/md/sm to modifiers' do
        { lg: 'usa-button--lg', md: 'usa-button--md', sm: 'usa-button--sm' }.each do |s, mod|
          rendered = render_inline(ButtonComponent.new(size: s).with_content('x'))
          expect(rendered).to have_css(".#{mod}")
        end
      end

      it 'ignores the legacy boolean API in the nds bucket' do
        rendered = render_inline(
          ButtonComponent.new(big: true, outline: true, variant: :secondary)
            .with_content('x'),
        )
        expect(rendered).to have_css('.usa-button--secondary')
        expect(rendered).not_to have_css('.usa-button--big')
        expect(rendered).not_to have_css('.usa-button--outline')
      end

      it 'emits icon-position and icon-only classes' do
        left = render_inline(ButtonComponent.new(icon: :print).with_content('x'))
        expect(left).to have_css('.usa-button--icon-left')

        right = render_inline(
          ButtonComponent.new(icon: :print, icon_position: :right).with_content('x'),
        )
        expect(right).to have_css('.usa-button--icon-right')

        icon_only = render_inline(ButtonComponent.new(icon: :print))
        expect(icon_only).to have_css('.usa-button--icon-only')
      end

      it 'raises on an unknown variant (fetch guards the map)' do
        expect do
          render_inline(ButtonComponent.new(variant: :bogus).with_content('x'))
        end.to raise_error(KeyError)
      end
    end
  end
end

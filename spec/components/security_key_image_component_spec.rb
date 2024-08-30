require 'rails_helper'

RSpec.describe SecurityKeyImageComponent, type: :component do
  subject(:rendered) do
    render_inline(described_class.new(mobile: mobile, **tag_options))
  end

  let(:mobile) { false }
  let(:tag_options) { {} }

  it 'sets the role' do
    expect(rendered).to have_css('svg[role=img]')
  end

  context 'tag options' do
    let(:tag_options) do
      {
        class: %w[foo-bar foo-baz],
        foo: 1,
        data: { foo: 2 },
        aria: { foo: 3 },
      }
    end

    it 'sets attributes on the root element, including data- and aria- tags' do
      aggregate_failures do
        svg = rendered.at_css('svg')

        expect(svg['foo']).to eq('1')
        expect(svg['data-foo']).to eq('2')
        expect(svg['aria-foo']).to eq('3')
      end
    end

    it 'adds classes via class option' do
      expect(rendered).to have_css('.width-full.height-auto.foo-bar.foo-baz')
    end

    context 'with HTML-unsafe content added via attributes' do
      let(:tag_options) { { foo: 'aaa"<script>alert();</script>' } }

      it 'correctly escapes the content' do
        expect(rendered).to_not include('<script>')
      end
    end
  end

  it 'adds the alt text as a title tag' do
    expect(rendered.css('title').text).to eq(t('forms.webauthn_setup.step_2_image_alt'))
  end

  context 'on mobile' do
    let(:mobile) { true }

    it 'adds the mobile modifier class' do
      expect(rendered).to have_css('.security-key--mobile')
    end

    it 'uses the mobile alt text' do
      expect(rendered.css('title').text).to eq(t('forms.webauthn_setup.step_2_image_mobile_alt'))
    end
  end
end

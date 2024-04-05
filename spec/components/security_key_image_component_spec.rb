require 'rails_helper'

RSpec.describe SecurityKeyImageComponent, type: :component do
  subject(:rendered) do
    render_inline(described_class.new(mobile: mobile, **tag_options))
  end

  let(:mobile) { false }
  let(:tag_options) { {} }

  it 'sets the height, width and role' do
    aggregate_failures do
      svg = rendered.at_css('svg')

      expect(svg['height']).to eq('193')
      expect(svg['width']).to eq('420')
      expect(svg['role']).to eq('img')
    end
  end

  context 'tag options' do
    let(:tag_options) do
      {
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

require 'rails_helper'

RSpec.describe SecurityKeyImageComponent, type: :component do
  subject(:rendered) do
    render_inline(described_class.new(mobile: mobile))
  end

  let(:mobile) { false }

  it 'sets the height, width and role' do
    aggregate_failures do
      svg = rendered.at_css('svg')

      expect(svg['height']).to eq('193')
      expect(svg['width']).to eq('420')
      expect(svg['role']).to eq('img')
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

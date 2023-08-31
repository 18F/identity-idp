require 'rails_helper'

RSpec.describe WebauthnInputComponent, type: :component do
  let(:options) { {} }
  let(:component) { WebauthnInputComponent.new(**options) }
  subject(:rendered) { render_inline component }

  it 'renders element with expected attributes' do
    expect(rendered).to have_css('lg-webauthn-input[hidden]:not([platform])', visible: false)
  end

  it 'exposes boolean alias for platform option' do
    expect(component.platform?).to eq(false)
  end

  context 'with platform option' do
    context 'with platform option false' do
      let(:options) { { platform: false } }

      it 'renders without platform attribute' do
        expect(rendered).to have_css('lg-webauthn-input[hidden]:not([platform])', visible: false)
      end
    end

    context 'with platform option true' do
      let(:options) { { platform: true } }

      it 'renders with platform attribute' do
        expect(rendered).to have_css('lg-webauthn-input[hidden][platform]', visible: false)
      end
    end
  end

  context 'with tag options' do
    let(:options) { super().merge(data: { foo: 'bar' }) }

    it 'renders with additional attributes' do
      expect(rendered).to have_css('lg-webauthn-input[hidden][data-foo="bar"]', visible: false)
    end
  end
end

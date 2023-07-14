require 'rails_helper'

RSpec.describe WebauthnInputComponent, type: :component do
  let(:options) { {} }
  let(:component) { WebauthnInputComponent.new(**options) }
  subject(:rendered) { render_inline component }

  it 'renders element with expected attributes' do
    element = rendered.css('lg-webauthn-input').first

    expect(element.attr('hidden')).to be_present
    expect(element.attr('platform')).to be_nil
    expect(element.attr('passkey-supported-only')).to be_nil
    expect(element.attr('show-unsupported-passkey')).to be_nil
  end

  it 'exposes boolean alias for platform option' do
    expect(component.platform?).to eq(false)
  end

  it 'exposes boolean alias for passkey_supported_only option' do
    expect(component.passkey_supported_only?).to eq(false)
  end

  it 'exposes boolean alias for show_unsupported_passkey option' do
    expect(component.show_unsupported_passkey?).to eq(false)
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

  context 'with passkey_supported_only option' do
    context 'with passkey_supported_only option false' do
      let(:options) { { passkey_supported_only: false } }

      it 'renders without passkey-supported-only attribute' do
        expect(rendered).to have_css(
          'lg-webauthn-input[hidden]:not([passkey-supported-only])',
          visible: false,
        )
      end
    end

    context 'with passkey_supported_only option true' do
      let(:options) { { passkey_supported_only: true } }

      it 'renders with passkey-supported-only attribute' do
        expect(rendered).to have_css(
          'lg-webauthn-input[hidden][passkey-supported-only]',
          visible: false,
        )
      end
    end
  end

  context 'with show_unsupported_passkey option' do
    context 'with show_unsupported_passkey option false' do
      let(:options) { { show_unsupported_passkey: false } }

      it 'renders without show-unsupported-passkey attribute' do
        expect(rendered).to have_css(
          'lg-webauthn-input[hidden]:not([show-unsupported-passkey])',
          visible: false,
        )
      end
    end

    context 'with show_unsupported_passkey option true' do
      let(:options) { { show_unsupported_passkey: true } }

      it 'renders with show-unsupported-passkey attribute' do
        expect(rendered).to have_css(
          'lg-webauthn-input[hidden][show-unsupported-passkey]',
          visible: false,
        )
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

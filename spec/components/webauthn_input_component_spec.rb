require 'rails_helper'

RSpec.describe WebauthnInputComponent, type: :component do
  let(:options) { {} }
  let(:component) { WebauthnInputComponent.new(**options) }
  subject(:rendered) { render_inline component }

  it 'renders element with expected attributes' do
    expect(rendered).to have_css('lg-webauthn-input.js:not([show-unsupported-passkey])')
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
      let(:options) { super().merge(platform: false) }

      it 'renders as visible for js-enabled browsers' do
        expect(rendered).to have_css('lg-webauthn-input.js:not([show-unsupported-passkey])')
      end
    end

    context 'with platform option true' do
      let(:options) { super().merge(platform: true) }

      it 'renders as visible for js-enabled browsers' do
        expect(rendered).to have_css('lg-webauthn-input.js:not([show-unsupported-passkey])')
      end

      context 'with passkey_supported_only option' do
        context 'with passkey_supported_only option false' do
          let(:options) { super().merge(passkey_supported_only: false) }

          it 'renders as visible for js-enabled browsers' do
            expect(rendered).to have_css('lg-webauthn-input.js:not([show-unsupported-passkey])')
          end
        end

        context 'with passkey_supported_only option true' do
          let(:options) { super().merge(passkey_supported_only: true) }

          it 'renders as hidden' do
            expect(rendered).to have_css(
              'lg-webauthn-input[hidden]:not([show-unsupported-passkey])',
              visible: false,
            )
          end

          context 'with show_unsupported_passkey option' do
            context 'with show_unsupported_passkey option false' do
              let(:options) { super().merge(show_unsupported_passkey: false) }

              it 'renders as hidden' do
                expect(rendered).to have_css(
                  'lg-webauthn-input[hidden]:not([show-unsupported-passkey])',
                  visible: false,
                )
              end
            end

            context 'with show_unsupported_passkey option true' do
              let(:options) { super().merge(show_unsupported_passkey: true) }

              it 'renders with show-unsupported-passkey attribute' do
                expect(rendered).to have_css(
                  'lg-webauthn-input[hidden][show-unsupported-passkey]',
                  visible: false,
                )
              end
            end
          end
        end
      end
    end
  end

  context 'with tag options' do
    let(:options) { super().merge(data: { foo: 'bar' }) }

    it 'renders with additional attributes' do
      expect(rendered).to have_css('lg-webauthn-input[data-foo="bar"]')
    end
  end
end

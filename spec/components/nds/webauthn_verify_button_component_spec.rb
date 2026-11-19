require 'rails_helper'

RSpec.describe NDS::WebauthnVerifyButtonComponent, type: :component do
  let(:options) do
    {
      credentials: [],
      user_challenge: [],
    }
  end
  let(:content) { 'Authenticate' }
  subject(:rendered) do
    render_inline NDS::WebauthnVerifyButtonComponent.new(**options).with_content(content)
  end

  it 'renders element with expected attributes' do
    element = rendered.css('lg-webauthn-verify-button').first

    expect(element.attr('data-credentials')).to eq('[]')
    expect(element.attr('data-user-challenge')).to eq('[]')
    expect(rendered).to have_css('lg-submit-button', text: content)
  end

  it 'renders the hidden spinner the custom element toggles' do
    expect(rendered).to have_css(
      'lg-webauthn-verify-button .webauthn-verify-button__spinner[hidden]',
      text: t('two_factor_authentication.webauthn_authenticating'),
      visible: :all,
    )
  end

  it 'renders the submit button without the default spacing classes' do
    button = rendered.css('button.webauthn-verify-button__button[type=submit]').first

    expect(button.text.strip).to eq(content)
    expect(button.classes).to_not include('display-block', 'margin-y-3')
  end

  it 'renders hidden fields' do
    expect(rendered).to have_field('credential_id', type: :hidden, with: '')
    expect(rendered).to have_field('authenticator_data', type: :hidden, with: '')
    expect(rendered).to have_field('signature', type: :hidden, with: '')
    expect(rendered).to have_field('client_data_json', type: :hidden, with: '')
    expect(rendered).to have_field('webauthn_error', type: :hidden, with: '')
    expect(rendered).to have_field('screen_lock_error', type: :hidden, with: '')
  end

  it 'reuses the default webauthn verify button script' do
    expect(described_class.scripts).to include('webauthn_verify_button_component')
  end

  context 'with tag options' do
    let(:options) { super().merge(data: { foo: 'bar' }) }

    it 'renders with additional attributes' do
      expect(rendered).to have_css('lg-webauthn-verify-button[data-credentials][data-foo]')
    end
  end
end

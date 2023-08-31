require 'rails_helper'

RSpec.describe WebauthnVerifyButtonComponent, type: :component do
  let(:options) do
    {
      credentials: [],
      user_challenge: [],
    }
  end
  let(:content) { 'Authenticate' }
  subject(:rendered) do
    render_inline WebauthnVerifyButtonComponent.new(**options).with_content(content)
  end

  it 'renders element with expected attributes' do
    element = rendered.css('lg-webauthn-verify-button').first

    expect(element.attr('data-credentials')).to eq('[]')
    expect(element.attr('data-user-challenge')).to eq('[]')
    expect(rendered).to have_button(content)
  end

  it 'renders hidden fields' do
    expect(rendered).to have_field('credential_id', type: :hidden, with: '')
    expect(rendered).to have_field('authenticator_data', type: :hidden, with: '')
    expect(rendered).to have_field('signature', type: :hidden, with: '')
    expect(rendered).to have_field('client_data_json', type: :hidden, with: '')
    expect(rendered).to have_field('webauthn_error', type: :hidden, with: '')
  end

  context 'with tag options' do
    let(:options) { super().merge(data: { foo: 'bar' }) }

    it 'renders with additional attributes' do
      expect(rendered).to have_css('lg-webauthn-verify-button[data-credentials][data-foo]')
    end
  end
end

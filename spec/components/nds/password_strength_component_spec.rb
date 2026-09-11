require 'rails_helper'

RSpec.describe NDS::PasswordStrengthComponent, type: :component do
  def render_strength(**opts)
    render_inline(NDS::PasswordStrengthComponent.new(input_id: 'user_password', **opts))
  end

  it 'renders the lg-nds-password-strength host, hidden with data-open=false' do
    host = render_strength.css('lg-nds-password-strength').first
    expect(host).to be_present
    expect(host['hidden']).to be_present
    expect(host['data-open']).to eq('false')
  end

  it 'wires input-id, minimum-length and forbidden-passwords attributes' do
    host = render_strength(minimum_length: 12, forbidden_passwords: ['password']).css(
      'lg-nds-password-strength',
    ).first
    expect(host['input-id']).to eq('user_password')
    expect(host['minimum-length']).to eq('12')
    expect(JSON.parse(host['forbidden-passwords'])).to eq(['password'])
  end

  it 'emits the password-strength contract classes' do
    rendered = render_strength
    expect(rendered).to have_css('lg-nds-password-strength.password-strength', visible: :all)
    expect(rendered).to have_css('.password-strength__inner .password-strength__row', visible: :all)
    expect(rendered).to have_css(
      '.password-strength__track[aria-hidden="true"] .password-strength__bar',
      visible: :all,
    )
    expect(rendered).to have_css(
      '.password-strength__feedback#user_password-password-strength[aria-live="polite"]',
      visible: :all,
    )
  end

  it 'merges extra class and data options onto the host' do
    host = render_strength(class: 'margin-top-2', data: { foo: 'bar' }).css(
      'lg-nds-password-strength',
    ).first
    expect(host['class']).to include('password-strength')
    expect(host['class']).to include('margin-top-2')
    expect(host['data-foo']).to eq('bar')
  end
end

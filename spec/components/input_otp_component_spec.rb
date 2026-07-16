require 'rails_helper'

RSpec.describe InputOtpComponent, type: :component do
  let(:view_context) { vc_test_controller.view_context }
  let(:form_object) { User.new }
  let(:form) do
    ActionView::Helpers::FormBuilder.new(:verification, form_object, view_context, {})
  end

  before do
    stub_const('TwoFactorAuthenticatable::DIRECT_OTP_LENGTH', 6)
  end

  it 'submits the OTP with accessible autofill and numeric input semantics' do
    rendered = render_inline described_class.new(form:)
    input = rendered.at_css('input')

    expect(rendered).to have_css('input', count: 1)
    expect(rendered).to have_css('.ads-input-otp__slots[aria-hidden="true"]')
    expect(input['name']).to eq('verification[code]')
    expect(input['autocomplete']).to eq('one-time-code')
    expect(input['inputmode']).to eq('numeric')
    expect(input['pattern']).to eq('[0-9]{6}')
    expect(input['maxlength']).to eq('6')
    expect(input['required']).to eq('required')
    expect(rendered).to have_css("label[for='#{input['id']}']", text: 'One-time code')
    expect(rendered.at_css('lg-ads-input-otp')).not_to have_attribute('data-enhanced')
  end

  it 'allows a whole optional prefix before an alphanumeric code' do
    rendered = render_inline described_class.new(
      form:,
      numeric: false,
      optional_prefix: '#',
    )
    input = rendered.at_css('input')

    expect(input['pattern']).to eq('(?:#)?[a-zA-Z0-9]{6}')
    expect(input['maxlength']).to eq('7')
    expect(input['inputmode']).to eq('text')
  end

  it 'rejects a prefix that could be mistaken for code characters' do
    component = described_class.new(form:, numeric: false, optional_prefix: 'AB')

    expect(component).not_to be_valid
    expect(component.errors[:optional_prefix]).to include(
      'must include a character outside the code character set',
    )
  end

  it 'associates hint and server error text with the invalid input' do
    form_object.errors.add(:code, 'Enter the complete one-time code.')
    rendered = render_inline described_class.new(form:, hint: 'Enter the six-digit code.')
    input = rendered.at_css('input')

    expect(input['aria-invalid']).to eq('true')
    expect(input).to have_description(
      'Enter the six-digit code.',
      'Enter the complete one-time code.',
    )
  end

  it 'rejects slot groups that do not cover the configured code length' do
    component = described_class.new(form:, length: 6, groups: [2, 2])

    expect(component).not_to be_valid
    expect(component.errors[:groups]).to include('must sum to length')
  end

  it 'reports invalid lengths without raising from dependent validations' do
    [nil, 'six'].each do |length|
      component = described_class.new(form:, length:)

      expect { component.valid? }.not_to raise_error
      expect(component).not_to be_valid
      expect(component.errors[:length]).to be_present
    end
  end

  it 'uses the form builder field identity for nested indexed forms' do
    nested_form = ActionView::Helpers::FormBuilder.new(
      'account[users_attributes][0]',
      form_object,
      view_context,
      {},
    )
    input = render_inline(described_class.new(form: nested_form)).at_css('input')

    expect(input['id']).to eq('account_users_attributes_0_code')
    expect(input['name']).to eq('account[users_attributes][0][code]')
  end

  it 'sizes unequal groups in proportion to their slot counts' do
    rendered = render_inline described_class.new(form:, length: 6, groups: [2, 4])

    expect(rendered).to have_css(
      '.ads-input-otp__group[style="--ads-input-otp-group-size: 2"]',
    )
    expect(rendered).to have_css(
      '.ads-input-otp__group[style="--ads-input-otp-group-size: 4"]',
    )
  end
end

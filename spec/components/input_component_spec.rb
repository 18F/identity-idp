require 'rails_helper'

RSpec.describe InputComponent, type: :component do
  let(:view_context) { vc_test_controller.view_context }
  let(:form) do
    ActionView::Helpers::FormBuilder.new(:preview, nil, view_context, {})
  end
  let(:options) { {} }

  subject(:rendered) do
    render_inline InputComponent.new(
      form:,
      attribute: :email,
      label: 'Email address',
      **options,
    )
  end

  it 'associates the visible label with the input via for/id' do
    input_id = rendered.css('input').first['id']

    expect(input_id).to be_present
    expect(rendered).to have_css("label[for='#{input_id}']", text: 'Email address')
  end

  it 'uses a custom input id for the label association' do
    rendered = render_inline InputComponent.new(
      form:,
      attribute: :email,
      label: 'Email address',
      id: 'custom-email',
    )

    expect(rendered).to have_css('label[for="custom-email"]')
    expect(rendered).to have_css('input#custom-email')
  end

  context 'with custom validation error messages' do
    let(:options) do
      {
        attribute: :name,
        label: 'Key nickname',
        error_messages: { valueMissing: 'Enter a nickname' },
      }
    end

    it 'includes the override in the validation messages data attribute' do
      messages = JSON.parse(rendered.css('.ads-input').first['data-ads-validation-messages'])

      expect(messages['valueMissing']).to eq('Enter a nickname')
    end
  end

  context 'with an error message' do
    let(:options) { { error_message: 'Enter a valid email address.' } }

    it 'marks the input invalid and describes it with the error' do
      input = rendered.css('input').first
      error_id = input['aria-describedby']

      expect(error_id).to be_present
      expect(input['aria-invalid']).to eq('true')
      expect(rendered).to have_css("##{error_id}", text: 'Enter a valid email address.')
    end

    it 'normalizes string aria keys without duplicating attributes' do
      rendered = render_inline InputComponent.new(
        form:,
        attribute: :email,
        label: 'Email address',
        error_message: 'Invalid',
        aria: { 'describedby' => 'hint', 'invalid' => false },
      )

      expect(rendered).to have_css('input[aria-describedby="hint preview_email_ads_error"]')
      expect(rendered).to have_css('input[aria-invalid=false]')
    end
  end

  context 'password' do
    let(:options) { { type: :password, attribute: :password, label: 'Password' } }

    it 'wires the toggle to the input with accessible name and pressed state' do
      input_id = rendered.css('input').first['id']

      expect(input_id).to be_present
      expect(rendered).to have_css("label[for='#{input_id}']", text: 'Password')
      expect(rendered).to have_css(
        "button[aria-controls='#{input_id}']" \
        "[aria-pressed=false][aria-label='#{t('components.password_toggle.toggle_label')}']",
      )
    end

    context 'with custom toggle labels' do
      let(:options) do
        {
          type: :password,
          attribute: :ssn,
          label: 'Social Security number',
          password_toggle_label: 'Show Social Security number',
          password_toggle_hide_label: 'Hide Social Security number',
        }
      end

      it 'uses the custom labels for the password toggle' do
        input_id = rendered.css('input').first['id']

        expect(rendered).to have_css(
          "button[aria-controls='#{input_id}']" \
          "[aria-label='Show Social Security number']" \
          "[data-label-show='Show Social Security number']" \
          "[data-label-hide='Hide Social Security number']",
        )
      end
    end
  end

  context 'phone with country selector' do
    let(:options) do
      {
        type: :tel,
        attribute: :phone,
        label: 'Phone number',
        country_selector: true,
      }
    end

    it 'associates accessible labels with the phone and country fields' do
      input = rendered.css('input[type=tel]').first
      select = rendered.css('select').first

      expect(input['id']).to be_present
      expect(select['id']).to be_present
      expect(rendered).to have_css("label[for='#{input['id']}']", text: 'Phone number')
      expect(rendered).to have_css(
        "label[for='#{select['id']}']",
        text: t('components.phone_input.country_code_label'),
      )
    end
  end
end

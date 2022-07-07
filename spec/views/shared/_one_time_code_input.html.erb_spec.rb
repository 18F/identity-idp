require 'rails_helper'

describe 'shared/_one_time_code_input.html.erb' do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:params) { {} }

  before do
    simple_form_for('', url: '/') do |f|
      render('shared/one_time_code_input', form: f, **params)
    end
  end

  describe 'name' do
    context 'no name given' do
      it 'renders default name "code"' do
        expect(rendered).to have_selector('[name="code"]')
      end
    end

    context 'name given' do
      let(:params) { { name: 'example' } }

      it 'renders given name' do
        expect(rendered).to have_selector('[name="example"]')
      end
    end
  end

  describe 'numeric' do
    context 'no numeric given' do
      it 'renders input mode "numeric"' do
        expect(rendered).to have_selector('[inputmode="numeric"]')
      end
    end

    context 'numeric is false' do
      let(:params) { { numeric: false } }

      it 'renders input mode "text"' do
        expect(rendered).to have_selector('[inputmode="text"]')
      end
    end
  end

  describe 'classes' do
    context 'without custom classes given' do
      it 'renders with default classes' do
        expect(rendered).to have_selector('.one-time-code-input')
      end
    end

    context 'with custom classes' do
      let(:params) { { class: 'my-custom-class' } }

      it 'renders with additional custom classes' do
        expect(rendered).to have_selector('.one-time-code-input.my-custom-class')
      end
    end
  end

  describe 'transport' do
    context 'omitted' do
      it 'renders default sms transport' do
        expect(rendered).to have_selector('[data-transport="sms"]')
      end
    end

    context 'given' do
      let(:params) { { transport: 'example' } }

      it 'renders given transport' do
        expect(rendered).to have_selector('[data-transport="example"]')
      end
    end

    context 'explicitly nil' do
      let(:params) { { transport: nil } }

      it 'renders without transport' do
        expect(rendered).not_to have_selector('[data-transport]')
      end
    end
  end

  describe 'aria attributes' do
    let(:params) { { aria: { hidden: true } } }

    it 'merges aria attributes' do
      expect(rendered).to have_selector('[aria-invalid="false"][aria-hidden="true"]')
    end
  end

  describe 'data attributes' do
    let(:params) { { data: { foo: 'bar' } } }

    it 'merges data attributes' do
      expect(rendered).to have_selector('[data-transport][data-foo="bar"]')
    end
  end
end

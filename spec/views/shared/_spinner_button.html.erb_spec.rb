require 'rails_helper'

describe 'shared/_spinner_button.html.erb' do
  it 'raises an error if no block given' do
    expect { render 'shared/spinner_button' }.to raise_error('no block content given')
  end

  describe 'classes' do
    let(:classes) { nil }

    before do
      render('shared/spinner_button', class: classes) { tag.button }
    end

    context 'without custom classes given' do
      let(:classes) { nil }

      it 'renders with default classes' do
        expect(rendered).to have_selector('.spinner-button')
      end
    end

    context 'with custom classes' do
      let(:classes) { 'my-custom-class' }

      it 'renders with additional custom classes' do
        expect(rendered).to have_selector('.spinner-button.my-custom-class')
      end
    end
  end

  describe 'action message' do
    let(:action_message) { nil }

    before do
      render('shared/spinner_button', action_message: action_message) { tag.button }
    end

    context 'without action message' do
      let(:action_message) { nil }

      it 'omits action message element' do
        expect(rendered).to_not have_selector('.spinner-button__action-message')
      end
    end

    context 'with action message' do
      let(:action_message) { 'Verifying...' }

      it 'renders action message element' do
        expect(rendered).to have_selector(
          '.spinner-button__action-message[data-message="Verifying..."]',
          text: '',
        )
      end
    end
  end
end

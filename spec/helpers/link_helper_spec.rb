require 'rails_helper'

RSpec.describe LinkHelper do
  include LinkHelper

  describe '#button_or_link_to' do
    let(:method) { nil }
    let(:text) { 'Example' }
    let(:url) { '#example' }
    let(:css_class) { 'example-class' }

    subject do
      button_or_link_to(text, url, method: method, class: css_class)
    end

    context 'without method assigned' do
      let(:method) { nil }

      it 'renders a link' do
        expect(subject).to have_selector("a.#{css_class}[href='#{url}']")
        expect(subject).to_not have_selector('[data-method]')
        expect(subject).to have_text(text)
      end
    end

    context 'with get method' do
      let(:method) { :get }

      it 'renders a link' do
        expect(subject).to have_selector("a.#{css_class}[href='#{url}']")
        expect(subject).to_not have_selector('[data-method]')
        expect(subject).to have_text(text)
      end
    end

    context 'with non-get method' do
      let(:method) { :delete }

      it 'renders a form' do
        expect(subject).to have_selector("form[action='#{url}']")
        expect(subject).to have_selector("input[name='_method'][value='#{method}']", visible: :all)
        expect(subject).to have_selector("button.#{css_class}[type='submit']")
        expect(subject).to have_text(text)
      end
    end
  end
end

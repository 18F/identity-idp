require 'rails_helper'

RSpec.describe LinkHelper do
  include LinkHelper

  describe '#new_window_link_to' do
    let(:name) { 'Link' }
    let(:html_options) { {} }

    subject(:link) { new_window_link_to(name, '', **html_options) }

    it 'opens in a new tab' do
      expect(link).to have_css('[target=_blank]')
    end

    it 'includes an accessibility hint about opening in a new tab' do
      expect(link).to have_content("#{name}#{t('links.new_window')}")
      expect(link).to have_css('.usa-sr-only', text: t('links.new_window'))
    end

    it 'adds design system external link class' do
      expect(link).to have_css('.usa-link--external')
    end

    context 'with unsafe html' do
      let(:name) { '<span data-unsafe>Link</span>' }

      it 'renders unsafe html as escaped' do
        expect(link).to have_content(name)
        expect(link).not_to have_css('[data-unsafe]')
      end
    end

    context 'with whitespace in the link text' do
      subject(:link) do
        new_window_link_to('', {}) do
          concat content_tag(:span, name)
          concat ' '
        end
      end

      it 'trims whitespace between link text and the accessible label' do
        # Regression: Safari's handling of the trailing whitespace would cause the external link
        # icon to be shown on a new line.
        expect(link).to have_content("#{name}#{t('links.new_window')}")
      end
    end

    context 'with custom classes' do
      let(:html_options) { { class: 'example' } }

      it 'adds design system external link class' do
        expect(link).to have_css('.example.usa-link--external')
      end

      context 'with custom classes as array' do
        let(:html_options) { { class: ['example'] } }

        it 'adds design system external link class' do
          expect(link).to have_css('.example.usa-link--external')
        end
      end
    end

    context 'content given as block' do
      subject(:link) { new_window_link_to('/url', **html_options) { name } }

      it 'renders a link with the expected attributes' do
        expect(link).to have_css(
          '.usa-link--external[href="/url"][target=_blank]',
          text: "#{name}#{t('links.new_window')}",
        )
      end

      context 'with additional html options' do
        let(:html_options) { { class: 'example', data: { foo: 'bar' } } }

        it 'renders attributes on the link' do
          expect(link).to have_css('.example.usa-link--external[data-foo="bar"]')
        end
      end
    end
  end

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

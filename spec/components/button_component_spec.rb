require 'rails_helper'

RSpec.describe ButtonComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::TagHelper

  let(:options) { {} }
  let(:content) { 'Button' }

  subject(:rendered) do
    render_inline ButtonComponent.new(**options).with_content(content)
  end

  it 'renders button content' do
    expect(rendered).to have_content(content)
  end

  it 'renders the primary large button by default' do
    expect(rendered).to have_css('button.ads-button.ads-button--primary.ads-button--lg')
  end

  context 'with variant' do
    let(:options) { { variant: :secondary } }

    it 'renders the variant class' do
      expect(rendered).to have_css('button.ads-button.ads-button--secondary')
    end
  end

  context 'with ghost variant' do
    let(:options) { { variant: :ghost } }

    it 'renders the ghost class' do
      expect(rendered).to have_css('button.ads-button.ads-button--ghost')
    end
  end

  context 'with destructive variant' do
    let(:options) { { variant: :destructive } }

    it 'renders the destructive class' do
      expect(rendered).to have_css('button.ads-button.ads-button--destructive')
    end
  end

  context 'with size' do
    let(:options) { { size: :lg } }

    it 'renders the size class' do
      expect(rendered).to have_css('button.ads-button.ads-button--lg')
    end
  end

  context 'with url' do
    let(:url) { '/' }
    let(:options) { { url: } }

    it 'renders link to url' do
      expect(rendered).to have_link(content, href: url)
    end

    context 'with method' do
      let(:method) { :put }
      let(:options) { super().merge(method:) }

      it 'renders button to url' do
        expect(rendered).to have_selector("form.ads-form__button-wrapper[action='#{url}']")
        expect(rendered).to have_selector("input[name='_method'][value='#{method}']", visible: :all)
        expect(rendered).to have_selector("button[type='submit']")
        expect(rendered).to have_text(content)
      end

      context 'with get method' do
        let(:method) { :get }

        it 'renders link to url' do
          expect(rendered).to have_link(content, href: url)
        end
      end
    end
  end
end

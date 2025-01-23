require 'rails_helper'

RSpec.describe 'idv/doc_auth/_back.html.erb' do
  let(:action) { nil }
  let(:step) { nil }
  let(:classes) { nil }
  let(:fallback_path) { nil }

  subject do
    render 'idv/shared/back', {
      action: action,
      step: step,
      class: classes,
      fallback_path: fallback_path,
    }
  end

  shared_examples 'back link with class' do
    let(:classes) { 'example-class' }

    it 'renders with class' do
      expect(subject).to have_css('.example-class')
    end
  end

  context 'with back path' do
    before do
      allow(view).to receive(:go_back_path).and_return('/example')
    end

    it 'renders with back path' do
      expect(subject).to have_selector('a[href="/example"]')
      expect(subject).to have_content('‹ ' + t('forms.buttons.back'))
    end
  end

  context 'with fallback link' do
    let(:fallback_path) { '/example' }

    it 'renders' do
      expect(subject).to have_selector('a[href="/example"]')
      expect(subject).to have_content('‹ ' + t('forms.buttons.back'))
    end

    it_behaves_like 'back link with class'
  end

  context 'no back path' do
    it 'renders nothing' do
      render 'idv/shared/back'

      expect(subject).to be_empty
    end
  end
end

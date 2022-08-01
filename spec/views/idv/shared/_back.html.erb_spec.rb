require 'rails_helper'

describe 'idv/doc_auth/_back.html.erb' do
  let(:flow) { nil }
  let(:action) { nil }
  let(:step) { nil }
  let(:classes) { nil }
  let(:fallback_path) { nil }

  subject do
    render 'idv/shared/back', {
      flow: flow,
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

  context 'with flow' do
    let(:flow) { 'doc_auth' }
    context 'with action' do
      let(:action) { 'redo_ssn' }

      it 'renders' do
        expect(subject).to have_selector("form[action='#{idv_doc_auth_step_path(step: 'redo_ssn')}']")
        expect(subject).to have_selector('input[name="_method"][value="put"]', visible: false)
        expect(subject).to have_selector("[type='submit']")
        expect(subject).to have_selector('button', text: '‹ ' + t('forms.buttons.back'))
      end

      it_behaves_like 'back link with class'
    end

    context 'with step' do
      let(:step) { 'verify' }

      it 'renders' do
        expect(subject).to have_selector("a[href='#{idv_doc_auth_step_path(step: 'verify')}']")
        expect(subject).to have_content('‹ ' + t('forms.buttons.back'))
      end

      it_behaves_like 'back link with class'
    end
  end

  context 'without flow' do
    context 'with action' do
      let(:action) { 'redo_ssn' }

      it 'renders nothing' do
        render 'idv/shared/back'

        expect(subject).to be_empty
      end
    end

    context 'with step' do
      let(:step) { 'verify' }

      it 'renders nothing' do
        render 'idv/shared/back'

        expect(subject).to be_empty
      end
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

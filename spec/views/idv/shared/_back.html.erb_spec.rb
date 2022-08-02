require 'rails_helper'

describe 'idv/doc_auth/_back.html.erb' do
  let(:step_url) { nil }
  let(:action) { nil }
  let(:step) { nil }
  let(:classes) { nil }
  let(:fallback_path) { nil }

  subject do
    render 'idv/shared/back', {
      step_url: step_url,
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

  context 'with step URL in locals' do
    let(:step_url) { :idv_doc_auth_step_url }

    context 'with action' do
      let(:action) { 'redo_ssn' }

      it 'renders' do
        expect(subject).to have_selector(
          "form[action='#{send(:idv_doc_auth_step_url, step: 'redo_ssn')}']",
        )
        expect(subject).to have_selector('input[name="_method"][value="put"]', visible: false)
        expect(subject).to have_selector("[type='submit']")
        expect(subject).to have_selector('button', text: '‹ ' + t('forms.buttons.back'))
      end

      it_behaves_like 'back link with class'
    end

    context 'with step' do
      let(:step) { 'verify' }

      it 'renders' do
        expect(subject).to have_selector(
          "a[href='#{send(
            :idv_doc_auth_step_url,
            step: 'verify',
          )}']",
        )
        expect(subject).to have_content('‹ ' + t('forms.buttons.back'))
      end

      it_behaves_like 'back link with class'
    end
  end

  context 'with step URL in instance variable' do
    before do
      assign(:step_url, :idv_doc_auth_step_url)
    end

    context 'with action' do
      let(:action) { 'redo_ssn' }

      it 'renders' do
        expect(subject).to have_selector(
          "form[action='#{send(:idv_doc_auth_step_url, step: 'redo_ssn')}']",
        )
        expect(subject).to have_selector('input[name="_method"][value="put"]', visible: false)
        expect(subject).to have_selector("[type='submit']")
        expect(subject).to have_selector('button', text: '‹ ' + t('forms.buttons.back'))
      end

      it_behaves_like 'back link with class'
    end

    context 'with step' do
      let(:step) { 'verify' }

      it 'renders' do
        expect(subject).to have_selector(
          "a[href='#{send(
            :idv_doc_auth_step_url,
            step: 'verify',
          )}']",
        )
        expect(subject).to have_content('‹ ' + t('forms.buttons.back'))
      end

      it_behaves_like 'back link with class'
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

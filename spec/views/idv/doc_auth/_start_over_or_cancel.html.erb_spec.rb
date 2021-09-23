require 'rails_helper'

describe 'idv/doc_auth/_start_over_or_cancel.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:locals) { {} }

  subject do
    render 'idv/doc_auth/start_over_or_cancel', **locals
  end

  describe 'hide start over' do
    context 'without hide_start_over value given' do
      it 'shows start over link' do
        expect(subject).to have_button(t('doc_auth.buttons.start_over'))
      end
    end

    context 'with hide_start_over as false' do
      let(:locals) { { hide_start_over: false } }

      it 'shows start over link' do
        expect(subject).to have_button(t('doc_auth.buttons.start_over'))
      end
    end

    context 'with hide_start_over as true' do
      let(:locals) { { hide_start_over: true } }

      it 'does not show start over link' do
        expect(subject).not_to have_button(t('doc_auth.buttons.start_over'))
      end
    end
  end

  context 'with step local' do
    let(:step) { 'first' }
    let(:locals) { { step: step } }

    it 'creates links with step parameter' do
      expect(subject).to have_link(t('links.cancel', href: idv_cancel_path(step: step)))
      expect(subject).to have_css("form[action='#{idv_session_path(step: step)}']")
    end
  end
end

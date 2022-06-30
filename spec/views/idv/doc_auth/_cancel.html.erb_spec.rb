require 'rails_helper'

describe 'idv/doc_auth/_cancel.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:locals) { {} }

  subject do
    render 'idv/doc_auth/cancel', **locals
  end

  it 'renders cancel link' do
    expect(subject).to have_link(t('links.cancel', href: idv_cancel_path))
  end

  context 'with step local' do
    let(:step) { 'first' }
    let(:locals) { { step: step } }

    it 'creates links with step parameter' do
      expect(subject).to have_link(t('links.cancel', href: idv_cancel_path(step: step)))
    end
  end
end

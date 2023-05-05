require 'rails_helper'

describe 'idv/doc_auth/agreement' do
  let(:flow_session) { {} }

  before do
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:url_for).and_wrap_original do |method, *args, &block|
      method.call(*args, &block)
    rescue
      ''
    end
    render
  end

  it 'renders a link to the privacy & security page' do
    expect(rendered).to have_link(
      t('doc_auth.instructions.learn_more'),
      href: policy_redirect_url(flow: :idv, step: :agreement, location: :consent),
    )
  end
end

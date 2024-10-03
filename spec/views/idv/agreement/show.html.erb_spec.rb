require 'rails_helper'

RSpec.describe 'idv/agreement/show' do
  let(:consent_form) do
    Idv::ConsentForm.new
  end

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:url_for).and_wrap_original do |method, *args, &block|
      method.call(*args, &block)
    rescue
      ''
    end
    assign :consent_form, consent_form
    render
  end

  it 'includes code to track clicks on the consent checkbox' do
    selector = [
      'lg-click-observer[event-name="IdV: consent checkbox toggled"]',
      '[name="doc_auth[idv_consent_given]"]',
    ].join ' '

    expect(rendered).to have_css(selector)
  end

  it 'renders a step indicator with Getting started as the current step' do
    expect(view.content_for(:pre_flash_content)).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.getting_started'),
    )
  end

  it 'renders a link to the privacy & security page' do
    expect(rendered).to have_link(
      t('doc_auth.instructions.learn_more'),
      href: policy_redirect_url(
        policy: :security_and_privacy_practices,
        flow: :idv,
        step: :agreement,
        location: :consent,
      ),
    )
  end
end

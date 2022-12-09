require 'rails_helper'

describe 'idv/inherited_proofing/get_started.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:flow_session) { {} }
  let(:sp_name) { 'test' }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view).to receive(:user_signing_up?).and_return(true)

    @presenter = instance_double(Idv::InheritedProofing::InheritedProofingPresenter)
    allow(@presenter).to receive(:learn_more_phone_or_mail_url).and_return('https://www.va.gov/resources/managing-your-vagov-profile/')
    allow(@presenter).to receive(:get_help_url).and_return('https://www.va.gov/resources/managing-your-vagov-profile/')
    allow(view).to receive(:presenter).and_return(@presenter)
  end

  it 'renders the Continue button' do
    render template: 'idv/inherited_proofing/get_started'

    expect(rendered).to have_button(t('inherited_proofing.buttons.continue'))
  end

  it 'renders the Cancel link' do
    render template: 'idv/inherited_proofing/get_started'

    expect(rendered).to have_link(t('links.cancel_account_creation'))
  end

  context 'with or without service provider' do
    it 'renders troubleshooting options' do
      render template: 'idv/inherited_proofing/get_started'

      expect(rendered).to have_link(
        t('inherited_proofing.troubleshooting.options.learn_more_phone_or_mail'),
      )
      expect(rendered).not_to have_link(nil, href: idv_inherited_proofing_return_to_sp_path)
      expect(rendered).to have_link(
        t(
          'inherited_proofing.troubleshooting.options.get_help',
          sp_name: sp_name,
        ),
      )
      expect(rendered).to have_link(
        t('inherited_proofing.troubleshooting.options.learn_more_phone_or_mail'),
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
      )
    end
  end
end

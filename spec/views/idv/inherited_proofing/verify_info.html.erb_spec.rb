require 'rails_helper'

describe 'idv/inherited_proofing/verify_info.html.erb' do
  let(:flow_session) { {} }
  let(:sp_name) { nil }
  let(:locale) { nil }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
  end

  it 'renders the Continue button' do
    render template: 'idv/inherited_proofing/verify_info'

    expect(rendered).to have_button(t('inherited_proofing.buttons.continue'))
  end

  it 'renders content' do
    render template: 'idv/inherited_proofing/verify_info'

    expect(rendered).to have_content('Place holder to show Please verify your information')
  end
end

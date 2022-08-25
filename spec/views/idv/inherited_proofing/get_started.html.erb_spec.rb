require 'rails_helper'

describe 'idv/inherited_proofing/get_started.html.erb' do
  let(:flow_session) { {} }
  let(:sp_name) { nil }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
  end

  it 'renders the Continue button' do
    render template: 'idv/inherited_proofing/get_started'

    expect(rendered).to have_button(t('inherited_proofing.buttons.continue'))
  end
end

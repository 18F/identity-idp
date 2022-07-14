require 'rails_helper'

describe 'idv/cancellations/destroy.html.erb' do
  before { render }

  it 'renders heading' do
    expect(rendered).to have_text(t('idv.cancel.headings.confirmation.hybrid'))
  end

  it 'renders content' do
    expect(rendered).to have_text(t('doc_auth.instructions.switch_back'))
  end
end

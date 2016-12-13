require 'rails_helper'

describe 'verify/finance/new.html.slim' do
  before do
    allow(view).to receive(:idv_finance_form).and_return(Idv::FinanceForm.new({}))
  end

  it 'displays the correct progress step' do
    render

    expect(rendered).to have_css('.step-5.active')
  end
end

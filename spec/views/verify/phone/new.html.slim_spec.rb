require 'rails_helper'

describe 'verify/phone/new.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    form = Idv::PhoneForm.new({}, user)
    allow(view).to receive(:idv_phone_form).and_return(form)
  end

  it 'displays the correct progress step' do
    render

    expect(rendered).to have_css('.step-6.active')
  end
end

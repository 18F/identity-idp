require 'rails_helper'

describe 'verify/sessions/new.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    form = Idv::ProfileForm.new({}, user)
    allow(view).to receive(:idv_profile_form).and_return(form)
  end

  it 'displays the correct progress step' do
    render

    expect(rendered).to have_css('.step-4.active')
  end
end

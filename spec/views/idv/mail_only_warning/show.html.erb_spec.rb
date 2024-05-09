require 'rails_helper'

RSpec.describe 'idv/mail_only_warning/show.html.erb' do
  before do
    allow(view).to receive(:step_indicator_steps).and_return([])
    allow(view).to receive(:current_sp).and_return(nil)

    allow(view).to receive(:exit_url).and_return('/exit_url')
  end

  it 'lists options with correct interpolation' do
    render

    expect(rendered).to include(APP_NAME)
  end
end

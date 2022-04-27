require 'rails_helper'

describe 'verify/show.html.erb' do
  subject(:rendered) { render }

  it 'renders application root element' do
    expect(rendered).to have_css('#app-root')
  end

  it 'enqueues app script' do
    expect_any_instance_of(ScriptHelper).to receive(:javascript_packs_tag_once).with('verify-flow')

    render
  end
end

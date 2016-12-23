require 'rails_helper'

describe 'verify/activated.html.slim' do
  it 'has a back link' do
    render

    expect(rendered).to have_link(
      t('forms.buttons.back'), href: verify_path
    )
  end
end

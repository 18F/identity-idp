require 'rails_helper'

RSpec.describe 'idv/hybrid_handoff/show.html.erb' do
  before do
    allow(view).to receive(:current_user).and_return(@user)
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
  end

  subject(:rendered) do
    render template: 'idv/hybrid_handoff/show', locals: {
      idv_phone_form: @idv_form,
    }
  end

  it 'has a form for starting mobile doc auth with an aria label tag' do
    expect(rendered).to have_selector(
      :xpath,
      "//form[@aria-label=\"#{t('forms.buttons.send_link')}\"]",
    )
  end

  it 'has a form for starting desktop doc auth with an aria label tag' do
    expect(rendered).to have_selector(
      :xpath,
      "//form[@aria-label=\"#{t('forms.buttons.upload_photos')}\"]",
    )
  end

  it 'displays the expected headings from the "a" case' do
    expect(rendered).to have_selector('h1', text: t('doc_auth.headings.hybrid_handoff'))
    expect(rendered).to have_selector('h2', text: t('doc_auth.headings.upload_from_phone'))
  end
end

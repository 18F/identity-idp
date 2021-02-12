require 'rails_helper'

describe 'idv/doc_auth/_back.html.erb' do
  it 'renders with action' do
    render 'idv/doc_auth/back', action: 'redo_ssn'

    expect(rendered).to have_selector("form[action='#{idv_doc_auth_step_path(step: 'redo_ssn')}']")
    expect(rendered).to have_selector('input[name="_method"][value="put"]', visible: false)
    expect(rendered).to have_selector("[type='submit'][value='#{'‹ ' + t('forms.buttons.back')}']")
  end

  it 'renders with step' do
    render 'idv/doc_auth/back', step: 'verify'

    expect(rendered).to have_selector("a[href='#{idv_doc_auth_step_path(step: 'verify')}']")
    expect(rendered).to have_content('‹ ' + t('forms.buttons.back'))
  end

  it 'renders with back path' do
    allow(view).to receive(:go_back_path).and_return('/example')

    render 'idv/doc_auth/back'

    expect(rendered).to have_selector('a[href="/example"]')
    expect(rendered).to have_content('‹ ' + t('forms.buttons.back'))
  end

  it 'renders fallback path' do
    render 'idv/doc_auth/back', fallback_path: '/example'

    expect(rendered).to have_selector('a[href="/example"]')
    expect(rendered).to have_content('‹ ' + t('forms.buttons.back'))
  end

  it 'renders nothing if there is no back path' do
    render 'idv/doc_auth/back'

    expect(rendered).to be_empty
  end
end

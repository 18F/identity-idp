require 'rails_helper'

describe 'idv/doc_auth/_back.html.erb' do
  it 'throws without any assigns' do
    expect { render 'idv/doc_auth/back' }.to raise_error('must pass one of action, step, or path')
  end

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

  it 'renders with path' do
    render 'idv/doc_auth/back', path: '/example'

    expect(rendered).to have_selector('a[href="/example"]')
    expect(rendered).to have_content('‹ ' + t('forms.buttons.back'))
  end
end

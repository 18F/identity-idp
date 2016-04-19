describe 'devise/sessions/new.html.slim' do
  before do
    allow(view).to receive(:resource).and_return(build_stubbed(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('upaya.titles.visitors.index'))

    render
  end

  it 'has a localized h2 headings' do
    render

    expect(rendered).to have_selector('h2', t('upaya.headings.log_in'))
    expect(rendered).
      to have_selector('h2', t('upaya.headings.visitors.new_account'))
  end

  it 'links to the privacy act statement' do
    render

    expect(rendered).
      to have_link(
        'Privacy Act Statement', href: 'terms#privacy')
  end

  it 'links to the Paperwork Reduction Act Reporting Burden' do
    render

    expect(rendered).
      to have_link(
        'Paperwork Reduction Act Reporting Burden', href: 'terms#pra')
  end

  it 'links to Accessibility Policy' do
    render

    expect(rendered).
      to have_link(
        'Accessibility Policy', href: 'http://upaya.18f.gov/accessibility')
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(
        t('upaya.forms.buttons.new_account'), href: new_user_registration_path)
  end

  it 'renders the modals/_privacy_statement partial' do
    render

    expect(view).to render_template('modals/_privacy_statement')
  end

  it 'renders the modals/_pra_statement partial' do
    render

    expect(view).to render_template('modals/_pra_statement')
  end

  it 'renders the shared/_privacy_text partial' do
    render

    expect(view).to render_template('shared/_privacy_text')
  end

  it 'renders the shared/_pra_text partial' do
    render

    expect(view).to render_template('shared/_pra_text')
  end
end

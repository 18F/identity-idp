describe 'terms/index.html.slim' do
  it 'renders the smallprint template' do
    render

    expect(view).to render_template('terms/_smallprint')
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

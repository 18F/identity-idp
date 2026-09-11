require 'rails_helper'

RSpec.describe NDS::PageShellComponent, type: :component do
  before do
    # Chrome + footer sub-renders reach controller helpers; the shell's own
    # class contract is what these specs assert. Stub the bucket true so nested
    # bucket-conditional ButtonComponents (footer) resolve nds.
    allow_any_instance_of(BaseComponent).to receive(:nds_bucket?).and_return(true)
  end

  def render_shell(**opts, &block)
    render_inline(NDS::PageShellComponent.new(hide_chrome: true, hide_footer: true, **opts), &block)
  end

  it 'renders the .auth-page shell with a main region' do
    rendered = render_shell { 'Body' }
    expect(rendered).to have_css('div.site.auth-page')
    expect(rendered).to have_css('main.auth-page__main#main-content', text: 'Body')
  end

  it 'puts data-nds-page-transition on the .auth-page element (not body) by default' do
    rendered = render_shell { 'Body' }
    expect(rendered).to have_css('div.auth-page[data-nds-page-transition]')
  end

  it 'omits the transition attribute when transition: false' do
    rendered = render_shell(transition: false) { 'Body' }
    expect(rendered).not_to have_css('[data-nds-page-transition]')
  end

  it 'emits width/density/align/surface modifiers (unprefixed)' do
    rendered = render_shell(
      width: :form, density: :spacious, align: :start, surface: :overlay,
    ) { 'x' }
    expect(rendered).to have_css(
      '.auth-page.auth-page--width-form.auth-page--density-spacious' \
      '.auth-page--align-start.auth-page--surface-overlay',
    )
  end

  it 'dasherizes multi-word modifier values' do
    rendered = render_shell(density: :mobile_compact, align: :mobile_start) { 'x' }
    expect(rendered).to have_css('.auth-page--density-mobile-compact.auth-page--align-mobile-start')
  end

  it 'uses a div main (no main-content id) when main_tag: :div' do
    rendered = render_shell(main_tag: :div) { 'x' }
    expect(rendered).to have_css('div.auth-page__main')
    expect(rendered).not_to have_css('#main-content')
  end

  it 'validates modifier values' do
    expect do
      render_inline(
        NDS::PageShellComponent.new(width: :bogus, hide_chrome: true, hide_footer: true),
      )
    end.to raise_error(ActiveModel::ValidationError)
  end

  it 'renders a footer wrapper slot when not hidden' do
    rendered = render_inline(
      NDS::PageShellComponent.new(hide_chrome: true),
    ) do |shell|
      shell.with_footer { 'custom footer' }
      'body'
    end
    expect(rendered).to have_css('.auth-page__footer-wrapper', text: 'custom footer')
  end
end

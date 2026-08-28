require 'rails_helper'

RSpec.describe NDS::FormPageComponent, type: :component do
  it 'renders section.auth.auth--form-page with the title h1 in a centered stack' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'Sign in'))
    expect(rendered).to have_css('section.auth.auth--form-page')
    expect(rendered).to have_css(
      '.auth__header .stack.stack--align-center.auth__intro > h1', text: 'Sign in'
    )
    expect(rendered).not_to have_css('.auth__intro-description')
    expect(rendered).not_to have_css('.auth__header--with-media')
  end

  it 'renders the subtitle as an intro description' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'T', subtitle: 'Sub'))
    expect(rendered).to have_css('.auth__intro-description', text: 'Sub')
  end

  it 'renders the media slot and flags the header' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'T')) do |c|
      c.with_media { 'MEDIA' }
    end
    expect(rendered).to have_css('.auth__header.auth__header--with-media', text: 'MEDIA')
  end

  it 'renders the body slot inside auth__form-page-body' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'T')) do |c|
      c.with_body { 'BODY' }
    end
    expect(rendered).to have_css('.auth__form-page-body', text: 'BODY')
  end

  it 'renders the actions slot inside auth__actions' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'T')) do |c|
      c.with_actions { 'ACTIONS' }
    end
    expect(rendered).to have_css('.auth__actions', text: 'ACTIONS')
    expect(rendered).not_to have_css('hr.divider')
  end

  it 'renders a divider before actions when divider: true' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'T', divider: true)) do |c|
      c.with_actions { 'ACTIONS' }
    end
    expect(rendered).to have_css('hr.divider + .auth__actions', text: 'ACTIONS')
  end

  it 'renders the alert above the header by default' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'T')) do |c|
      c.with_alert { '<div class="my-alert">ALERT</div>'.html_safe }
    end
    expect(rendered).to have_css('.auth > .my-alert:first-child', text: 'ALERT')
  end

  it 'renders the alert below the header when alert_position: :below' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'T', alert_position: :below)) do |c|
      c.with_alert { '<div class="my-alert">ALERT</div>'.html_safe }
    end
    expect(rendered).to have_css('.auth__header + .my-alert', text: 'ALERT')
  end

  it 'passes through class_name and html options' do
    rendered = render_inline(NDS::FormPageComponent.new(title: 'T', class_name: 'extra', id: 'foo'))
    expect(rendered).to have_css('section.auth.auth--form-page.extra#foo')
  end

  it 'emits auth-namespaced classes across every slot' do
    component = NDS::FormPageComponent.new(title: 'T', subtitle: 'S', divider: true)
    rendered = render_inline(component) do |c|
      c.with_media { 'M' }
      c.with_body { 'B' }
      c.with_actions { 'A' }
    end
    expect(rendered).to have_css('section.auth.auth--form-page')
    expect(rendered).to have_css('.auth__header--with-media', text: 'M')
    expect(rendered).to have_css('.auth__intro-description', text: 'S')
    expect(rendered).to have_css('.auth__form-page-body', text: 'B')
    expect(rendered).to have_css('hr.divider + .auth__actions', text: 'A')
  end
end

require 'rails_helper'

RSpec.describe TabNavigationComponent, type: :component do
  let(:label) { 'Navigation' }
  let(:routes) { [{ path: '/first', text: 'First' }, { path: '/second', text: 'Second' }] }
  let(:tag_options) { { label:, routes: } }

  subject(:rendered) do
    render_inline TabNavigationComponent.new(**tag_options)
  end

  it 'renders labelled navigation' do
    expect(rendered).to have_css('.tab-navigation[aria-label="Navigation"]')
    expect(rendered).to have_css('li', count: 2)
    expect(rendered).to have_link('First') { |link| !is_current_link?(link) }
    expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
  end

  context 'with tag options' do
    let(:tag_options) { super().merge(data: { foo: 'bar' }, class: 'example') }

    it 'renders with tag options forwarded to navigation' do
      expect(rendered).to have_css('.tab-navigation.example[data-foo="bar"]')
    end
  end

  context 'with link for current request' do
    let(:request_path) { '/first' }
    let(:request_method) { 'GET' }

    around do |example|
      Rails.application.routes.draw do
        get '(:example_param)/first' => 'application#first'
        post '(:example_param)/first' => 'application#first_create'
        get '(:example_param)/second' => 'application#second'
        post '(:example_param)/second' => 'application#second_create'
      end

      with_request_url(request_path, method: request_method) { example.run }

      Rails.application.reload_routes!
    end

    it 'renders current link as highlighted' do
      expect(rendered).to have_css('li,[role=listitem]', count: 2)
      expect(rendered).to have_link('First') { |link| is_current_link?(link) }
      expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
    end

    it 'wraps link in click observer' do
      expect(rendered).to have_link('First') do |link|
        expect(link).to have_ancestor('lg-click-observer')
      end
      expect(rendered).to have_link('Second') do |link|
        expect(link).not_to have_ancestor('lg-click-observer')
      end
    end

    context 'with routes defining full URL' do
      let(:routes) do
        [
          { path: 'https://example.com/first', text: 'First' },
          { path: 'https://example.com/second', text: 'Second' },
        ]
      end

      it 'renders current link as highlighted' do
        expect(rendered).to have_link('First') { |link| is_current_link?(link) }
        expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
      end
    end

    context 'with routes including query parameters' do
      let(:routes) do
        [
          { path: '/first?example_param=example_param_value', text: 'First' },
          { path: '/second?example_param=example_param_value', text: 'Second' },
        ]
      end

      it 'renders current link as highlighted' do
        expect(rendered).to have_link('First') { |link| is_current_link?(link) }
        expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
      end
    end

    context 'with non-GET request' do
      let(:request_method) { 'POST' }

      it 'renders current link as highlighted' do
        expect(rendered).to have_link('First') { |link| is_current_link?(link) }
        expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
      end
    end

    context 'with equivalent routes based on param' do
      let(:routes) do
        [
          { path: '/example_param_value/first', text: 'First' },
          { path: '/example_param_value/second', text: 'Second' },
        ]
      end

      it 'renders current link as highlighted' do
        expect(rendered).to have_link('First') { |link| is_current_link?(link) }
        expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
      end
    end

    context 'unparseable route' do
      let(:routes) do
        [
          { path: '😬', text: 'First' },
          { path: '😬', text: 'Second' },
        ]
      end

      it 'renders gracefully without highlighted link' do
        expect(rendered).to have_link('First') { |link| !is_current_link?(link) }
        expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
      end
    end
  end

  def is_current_link?(link)
    link.matches_css?('[aria-current="page"].usa-button--outline')
  end
end

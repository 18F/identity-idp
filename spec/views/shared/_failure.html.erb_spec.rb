require 'rails_helper'

describe 'shared/_failure.html.erb' do
  let(:presenter) { FailurePresenter.new(:failure) }
  subject(:rendered) { render 'shared/failure', presenter: presenter }

  it 'renders icon' do
    expect(rendered).to have_css("img[src*='fail-x']")
    expect(rendered).not_to have_css('.page-heading')
    expect(rendered).not_to have_css('p')
    expect(rendered).not_to have_css('.troubleshooting-options')
    expect(rendered).not_to have_css('script', visible: :all)
  end

  context 'with content' do
    let(:header) { 'header' }
    let(:description) { 'description' }
    let(:troubleshooting_options) { [{ text: 'option', url: 'https://example.com' }] }

    before do
      allow(presenter).to receive(:header).and_return(header)
      allow(presenter).to receive(:description).and_return(description)
      allow(presenter).to receive(:troubleshooting_options).and_return(troubleshooting_options)
    end

    it 'renders content' do
      expect(rendered).to have_css("img[src*='fail-x']")
      expect(rendered).to have_css('.page-heading', text: header)
      expect(rendered).to have_css('p', text: description)
      expect(rendered).to have_css('.troubleshooting-options')
      expect(rendered).to have_link(
        troubleshooting_options[0][:text],
        href: troubleshooting_options[0][:url],
      )
    end

    context 'with array description' do
      let(:description_2) { 'description_2' }

      before do
        allow(presenter).to receive(:description).and_return([description, description_2])
      end

      it 'renders content' do
        expect(rendered).to have_css('p', text: description)
        expect(rendered).to have_css('p', text: description_2)
      end
    end
  end
end

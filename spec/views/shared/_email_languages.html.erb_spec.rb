require 'rails_helper'

RSpec.describe 'shared/_email_languages.html.erb' do
  include SimpleForm::ActionViewExtensions::FormHelper

  subject(:render_partial) do
    simple_form_for(:user, url: '/') do |f|
      render partial: 'shared/email_languages',
             locals: { f: f, selection: selection, labelledby: labelledby }
    end
  end

  let(:selection) { 'fr' }
  let(:labelledby) { 'outer-label-id' }

  it 'renders a checkbox per available locale' do
    render_partial

    doc = Nokogiri::HTML(rendered)
    radios = doc.css('input[type=radio]')

    expect(radios.map { |r| r['value'] }).to match_array(I18n.available_locales.map(&:to_s))
  end

  context 'accessibility' do
    it 'marks all radio boxes as labelled by the outer label' do
      render_partial

      doc = Nokogiri::HTML(rendered)
      radios = doc.css('input[type=radio]')

      radios.each do |radio|
        expect(radio['aria-labelledby']).to include(labelledby)
      end
    end

    it 'marks each radio box as labelled by its unique label' do
      render_partial

      doc = Nokogiri::HTML(rendered)
      radios = doc.css('input[type=radio]')

      radios.each do |radio|
        aria = radio['aria-labelledby']
        unique_label = (aria.split(' ') - [labelledby]).first
        expect(doc.css("label##{unique_label}").size).to eq(1)
      end
    end
  end

  context 'with a nil selection' do
    let(:selection) { nil }

    it 'marks the default language as checked' do
      render_partial

      doc = Nokogiri::HTML(rendered)
      checked = doc.css('input[type=radio][checked]')
      expect(checked.length).to eq(1)

      radio = checked.first
      expect(radio[:value]).to eq(I18n.default_locale.to_s)
    end
  end

  context 'with a language selection' do
    let(:selection) { 'es' }

    it 'marks the selection language as checked' do
      render_partial

      doc = Nokogiri::HTML(rendered)
      checked = doc.css('input[type=radio][checked]')
      expect(checked.length).to eq(1)

      radio = checked.first
      expect(radio[:value]).to eq(selection)
    end
  end
end

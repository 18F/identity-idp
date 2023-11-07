require 'rails_helper'

RSpec.describe 'shared/_email_languages.html.erb' do
  include SimpleForm::ActionViewExtensions::FormHelper

  subject(:render_partial) do
    simple_form_for(:user, url: '/') do |f|
      render partial: 'shared/email_languages',
             locals: { f:, selection:, labelledby: }
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

  it 'marks the current locale as the default' do
    render_partial

    doc = Nokogiri::HTML(rendered)
    english_input = doc.css('input[type=radio][value=en]').first
    english_label = doc.css("label[for=#{english_input[:id]}]").first
    expect(english_label.text).to eq('English (default)')

    others = doc.css('input[type=radio]:not([value=en])')
    others.each do |radio|
      label = doc.css("label[for=#{radio[:id]}]")
      expect(label.text).to_not include('(default)')
    end
  end

  context 'in french' do
    before { I18n.locale = :fr }

    it 'marks the current locale as the default' do
      render_partial

      doc = Nokogiri::HTML(rendered)
      french_input = doc.css('input[type=radio][value=fr]').first
      french_label = doc.css("label[for=#{french_input[:id]}]").first
      expect(french_label.text).to eq('Français (par défaut)')

      others = doc.css('input[type=radio]:not([value=fr])')
      others.each do |radio|
        label = doc.css("label[for=#{radio[:id]}]")
        expect(label.text).to_not include('(par défaut)')
      end
    end
  end
end

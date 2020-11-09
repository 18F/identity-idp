require 'rails_helper'

describe 'users/shared/_phone_number_edit.html.erb' do
  include SimpleForm::ActionViewExtensions::FormHelper
  include FormHelper

  subject(:render_partial) do
    simple_form_for(NewPhoneForm.new(build(:user)), url: '/') do |f|
      render partial: 'users/shared/phone_number_edit', locals: { f: f }
    end
  end

  it 'puts the US as the first country code option' do
    render_partial

    doc = Nokogiri::HTML(rendered)
    expect(doc.css('#new_phone_form_international_code > option').first[:value]).to eq('US')
  end

  it 'includes supported countries as a data attribute for the Javascript' do
    render_partial

    doc = Nokogiri::HTML(rendered)
    countries_data = doc.css('.international-code').first['data-countries']
    expect(countries_data).to eq(supported_country_codes.to_json)
  end
end

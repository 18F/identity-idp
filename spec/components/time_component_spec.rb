require 'rails_helper'

RSpec.describe TimeComponent, type: :component do
  it 'renders element with expected attributes and formatted time content' do
    rendered = render_inline TimeComponent.new(time: Time.zone.parse('2020-04-21T14:03:00Z').utc)

    expect(rendered).to have_css(
      'lg-time[data-timestamp="2020-04-21T14:03:00Z"][data-format]',
      text: 'April 21, 2020 at 2:03 PM',
    )
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline TimeComponent.new(
        time: Time.parse('2020-04-21T14:03:00Z'),
        data: { foo: 'bar' },
      )

      expect(rendered).to have_css('lg-time[data-timestamp][data-format][data-foo="bar"]')
    end
  end

  context 'with non-UTC timezone' do
    it 'renders in UTC timezone' do
      rendered = render_inline TimeComponent.new(time: Time.zone.parse('2022-02-19T03:29:43+10:00'))

      expect(rendered).to have_content('February 18, 2022 at 5:29 PM')
    end
  end

  context 'with 24-hour locale' do
    before do
      I18n.locale = :fr
    end

    it 'renders element with formatted time content' do
      rendered = render_inline TimeComponent.new(time: Time.zone.parse('2020-04-21T14:03:00Z').utc)

      expect(rendered).to have_content('21 April 2020 à 2 h 03 PM')
    end
  end
end

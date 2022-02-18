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
end

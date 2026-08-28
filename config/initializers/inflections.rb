# frozen_string_literal: true

# Register NDS as an acronym so Zeitwerk autoloads NDS-prefixed constants under
# the NDS name (e.g. app/components/nds_button_component.rb -> NDSButtonComponent)
# rather than expecting the camelized `Nds` form.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'NDS'
end

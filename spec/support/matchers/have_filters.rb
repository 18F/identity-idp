RSpec::Matchers.define :have_filters do |kind, *names|
  match do |controller|
    filters = controller._process_action_callbacks.select { |f| f.kind == kind }.map(&:filter)
    names.all? { |name| filters.include?(name) }
  end
end

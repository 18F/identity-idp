# Usage in a controller spec:
#
# it 'includes the appropriate before_actions' do
#   expect(subject).to have_filters(
#     :before,
#     :authenticate_scope!,
#     :verify_user_is_not_second_factor_locked,
#     :handle_two_factor_authentication,
#     :check_already_authenticated
#   )
# end
#
# The first parameter passed to the `have_filter` method is the kind of filter,
# such as :before for `before_action`. The rest of the parameters represent an
# array of the expected filters.
# If any of the filters have only: or except: options, such as:
# before_action :check_already_authenticated, only: :new,
# you can test it like this:
#
# it 'includes the appropriate before_actions' do
#   expect(subject).to have_filters(
#     :before,
#     :authenticate_scope!,
#     :verify_user_is_not_second_factor_locked,
#     :handle_two_factor_authentication,
#     [:check_already_authenticated, only: :new]
#   )
# end

RSpec::Matchers.define :have_filters do |kind, *names|
  match do |controller|
    callbacks = controller._process_action_callbacks.select { |callback| callback.kind == kind }

    filters = callbacks.each_with_object([]) do |f, result|
      result << f.filter unless filter_has_only_option?(f) || filter_has_except_option?(f)
      result << [f.filter, only: symbolized_only_action(f)] if filter_has_only_option?(f)
      result << [f.filter, except: symbolized_except_action(f)] if filter_has_except_option?(f)
    end

    names.all? { |name| filters.include?(name) }
  end
end

def filter_has_only_option?(filter)
  if_option_for(filter).present?
end

def filter_has_except_option?(filter)
  unless_option_for(filter).present?
end

def if_option_for(filter)
  filter.instance_variable_get(:@if)
end

def unless_option_for(filter)
  filter.instance_variable_get(:@unless)
end

def symbol_from_string(string)
  if string.include?('||')
    string.split('||').map { |s| s.split('==')[1].strip.tr("'", '').to_sym }
  else
    string.split('==')[1].strip.tr("'", '').to_sym
  end
end

def symbolized_only_action(filter)
  symbol_from_string(if_option_for(filter)[0])
end

def symbolized_except_action(filter)
  symbol_from_string(unless_option_for(filter)[0])
end

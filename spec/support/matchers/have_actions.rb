# Usage in a controller spec:
#
# it 'includes the appropriate before_actions' do
#   expect(subject).to have_actions(
#     :before,
#     :authenticate_scope!,
#     :verify_user_is_not_second_factor_locked,
#     :handle_two_factor_authentication,
#     :check_already_authenticated
#   )
# end
#
# The first parameter passed to the `have_action` method is the kind of action,
# such as :before for `before_action`. The rest of the parameters represent an
# array of the expected actions.
# If any of the actions have only: or except: options, such as:
# before_action :check_already_authenticated, only: :new,
# you can test it like this:
#
# it 'includes the appropriate before_actions' do
#   expect(subject).to have_actions(
#     :before,
#     :authenticate_scope!,
#     :verify_user_is_not_second_factor_locked,
#     :handle_two_factor_authentication,
#     [:check_already_authenticated, only: :new]
#   )
# end

RSpec::Matchers.define :have_actions do |kind, *names|
  match do |controller|
    callbacks = controller._process_action_callbacks.select { |callback| callback.kind == kind }

    actions = callbacks.each_with_object([]) do |f, result|
      result << f.filter unless action_has_only_option?(f) || action_has_except_option?(f)
      result << [f.filter, only: symbolized_only_action(f)] if action_has_only_option?(f)
      result << [f.filter, except: symbolized_except_action(f)] if action_has_except_option?(f)
    end

    names.all? { |name| actions.include?(name) }
  end
end

def action_has_only_option?(action)
  if_option_for(action).present?
end

def action_has_except_option?(action)
  unless_option_for(action).present?
end

def if_option_for(action)
  action.instance_variable_get(:@if)
end

def unless_option_for(action)
  action.instance_variable_get(:@unless)
end

def symbol_from_string(string)
  if string.include?('||')
    string.split('||').map { |s| s.split('==')[1].strip.tr("'", '').to_sym }
  else
    string.split('==')[1].strip.tr("'", '').to_sym
  end
end

def symbolized_only_action(action)
  symbol_from_string(if_option_for(action)[0])
end

def symbolized_except_action(action)
  symbol_from_string(unless_option_for(action)[0])
end

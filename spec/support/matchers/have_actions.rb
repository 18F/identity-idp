# Usage in a controller spec:
#
# it 'includes the appropriate before_actions' do
#   expect(subject).to have_actions(
#     :before,
#     :authenticate_user,
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
#     :authenticate_user,
#     :handle_two_factor_authentication,
#     [:check_already_authenticated, only: :new]
#   )
# end

RSpec::Matchers.define :have_actions do |kind, *names|
  match do |controller|
    callbacks = controller._process_action_callbacks.select { |callback| callback.kind == kind }

    actions = callbacks.each_with_object([]) do |f, result|
      result << f.filter unless action_has_only_option?(f) || action_has_except_option?(f)
      result << [f.filter, only: parsed_only_action(f)] if action_has_only_option?(f)
      result << [f.filter, except: parsed_except_action(f)] if action_has_except_option?(f)
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

def parsed_only_action(action)
  only_option = if_option_for(action)[0]

  "#{only_option.class}OptionParser".constantize.new(only_option).parse
end

def parsed_except_action(action)
  except_option = unless_option_for(action)[0]

  "#{except_option.class}OptionParser".constantize.new(except_option).parse
end

class ProcOptionParser
  def initialize(option)
    @option = option
  end

  def parse
    @option
  end
end

class StringOptionParser
  def initialize(option)
    @option = option
  end

  def parse
    if @option.include?('||')
      array_of_actions_passed_to_only_or_except_option_in_controller_callback
    else
      single_action_passed_to_only_or_except_option_in_controller_callback
    end
  end

  private

  def array_of_actions_passed_to_only_or_except_option_in_controller_callback
    @option.split('||').map { |str| str.split('==')[1].strip.tr("'", '').to_sym }
  end

  def single_action_passed_to_only_or_except_option_in_controller_callback
    @option.split('==')[1].strip.tr("'", '').to_sym
  end
end

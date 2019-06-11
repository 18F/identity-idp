require 'rails_helper'

# When a controller uses Strong Parameters such as:
# params.require(:user).permit(:email), the `user` param is assumed to
# be a Hash, but it's easy for a pentester (for example) to set the
# `user` param to a String instead, which by default would raise a 500
# error because the String class doesn't respond to `permit`. To get
# around that, we monkey patched the Ruby String class to raise an
# instance of ActionController::ParameterMissing, which will return
# a 400 error. 500 errors can potentially page people in the middle of
# the night, whereas 400 errors don't.
describe 'submitting email registration form with required param as String' do
  it 'raises ActionController::ParameterMissing' do
    params = { user: 'abcdef' }
    message_string = 'param is missing or the value is empty: #permit called on String'

    expect { post sign_up_register_path, params: params }.
      to raise_error(ActionController::ParameterMissing, message_string)
  end
end

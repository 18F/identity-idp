# When a controller uses Strong Parameters such as:
# params.require(:user).permit(:email), the `user` param is assumed to
# be a Hash, but it's easy for a pentester (for example) to set the
# `user` param to a String instead, which by default would raise a 500
# error because the String class doesn't respond to `permit`. To get
# around that, we monkey patched the Ruby String class to raise an
# instance of ActionController::ParameterMissing, which will return
# a 400 error. 500 errors can potentially page people in the middle of
# the night, whereas 400 errors don't.
module CoreExtensions
  module String
    module Permit
      def permit(*)
        raise ActionController::ParameterMissing, '#permit called on String'
      end
    end
  end
end

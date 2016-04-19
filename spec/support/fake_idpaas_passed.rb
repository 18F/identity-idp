require 'support/fake_idpaas'

class FakeIdpaasPassed < FakeIdpaas
  private

  def quiz_status(key)
    return 'PASSED' if key == 5

    'STARTED'
  end
end

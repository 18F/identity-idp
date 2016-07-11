class NullUser
  def confirmed?
    false
  end

  def send_confirmation_instructions
    # noop
  end
end

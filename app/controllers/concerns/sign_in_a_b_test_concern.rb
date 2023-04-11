module SignInABTestConcern
  def sign_in_a_b_test_bucket
    AbTests::SIGN_IN.bucket(sp_session[:request_id] || session.id)
  end
end

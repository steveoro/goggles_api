# frozen_string_literal: true

module APISessionHelpers
  # Returns a new JWT for the specified User instance
  def jwt_for_api_session(user)
    CmdAuthenticateUser.new(user.email, user.password).call.result
  end
end

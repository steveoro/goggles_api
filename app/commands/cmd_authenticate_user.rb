# frozen_string_literal: true

require 'simple_command'

#
# = Authenticate User command object
#
# Creates a valid JWT if the User exists and has a matching password; +nil+ otherwise.
# (Used by the '/session' endpoint)
#
#   - file vers.: 1.80
#   - author....: Steve A.
#   - build.....: 20210226
#
class CmdAuthenticateUser
  prepend SimpleCommand

  # Creates a new command object, given the parameters that make up the payload for the JWT
  def initialize(email, password)
    @email = email
    @password = password
  end

  # Sets #result as the JWT string identified by the user email & password when the user
  # can be authenticated.
  #
  # When unsuccessful, sets #result to +nil+ and logs the errors into the #errors hash.
  # Returns always itself.
  def call
    return unless authenticated_user

    GogglesDb::JwtManager.encode(
      { # Payload:
        user_id: authenticated_user.id
      },
      Rails.application.credentials.api_static_key
      # use defalt session length (@see GogglesDb::JwtManager::TOKEN_LIFE)
    )
  end
  #-- --------------------------------------------------------------------------
  #++

  private

  attr_accessor :email, :password

  # Returns a valid, authenticated +User+ instance or +nil+ otherwise.
  def authenticated_user
    user = GogglesDb::User.find_by_email(email)
    return user if user&.confirmed? && user&.valid_password?(password)

    # Add any errors to SimpleCommand internal list:
    if user && !user.confirmed?
      errors.add(:msg, I18n.t('api.message.unconfirmed_email'))
    else
      errors.add(:msg, I18n.t('api.message.invalid_credentials'))
    end
    nil
  end
end

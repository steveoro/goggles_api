# frozen_string_literal: true

require 'simple_command'

#
# = Authorize API Request command object
#
# Authorization command to be used after the API session has been established
# (used by any endpoint except '/session')
#
# Retrieves the User authorized for a generic API request, given the JWT specified in
# its headers Hash, using the internal API key for decoding it.
#
#   - file vers.: 1.80
#   - author....: Steve A.
#   - build.....: 20210226
#
class CmdAuthorizeAPIRequest
  prepend SimpleCommand

  # Creates a new command object, given the header Hash for the request
  def initialize(headers = {})
    @headers = headers
  end

  # Sets #result as the decoded API user.
  #
  # When unsuccessful, sets #result to +nil+ and logs the errors into the #errors hash.
  # Returns always itself.
  def call
    authenticated_user
  end
  #-- --------------------------------------------------------------------------
  #++

  private

  attr_reader :headers

  # Returns a valid, authenticated +User+ instance or +nil+ otherwise.
  def authenticated_user
    @api_user ||= GogglesDb::User.find(decoded_jwt_data[:user_id]) if decoded_jwt_data
    # (&&-ing with nil at the end will force nil as return value if @api_user is not set)
    @api_user || errors.add(:msg, I18n.t('api.message.jwt.invalid')) && nil
  end

  def decoded_jwt_data
    @decoded_jwt_data ||= GogglesDb::JWTManager.decode(jwt_from_auth_header, Rails.application.credentials.api_static_key)
  end

  # Retrieves the JWT from the 'Authorization' header
  def jwt_from_auth_header
    return nil unless headers.is_a?(Hash)
    return headers['Authorization'].split.last if headers['Authorization'].present?

    # Add any errors to SimpleCommand internal list:
    errors.add(:msg, I18n.t('api.message.jwt.missing'))
    nil
  end
end

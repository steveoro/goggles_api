# frozen_string_literal: true

module Goggles
  # = Goggles API v3: User API Grape controller
  #
  #   - version:  7-0.4.06
  #   - author:   Steve A.
  #   - build:    20210906
  #
  # Users should read or update just their data and should *not* have any access to
  # any other user row (unless authorized for CRUD on this entity).
  #
  class UsersAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :user do
      # GET /api/:version/user/:id
      #
      # == Returns:
      # The User instance matching the specified +id+ as JSON.
      #
      desc 'User details'
      params do
        requires :id, type: Integer, desc: 'User ID'
      end
      route_param :id do
        get do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud_or_has_id(api_user, 'User', params['id'].to_i)

          GogglesDb::User.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/user/:id
      #
      # Allow direct update for most of the User fields.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update User details'
      params do
        requires :id, type: Integer, desc: 'User ID'
        optional :name, type: String, desc: 'optional: User name'
        optional :first_name, type: String, desc: 'optional: first name'
        optional :last_name, type: String, desc: 'optional: last name'
        optional :description, type: String, desc: 'optional: User description - usually, first_name + blank + last_name'
        optional :year_of_birth, type: Integer, desc: 'optional: year of birth'
        optional :swimmer_id, type: Integer, desc: 'optional: associated Swimmer ID'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud_or_has_id(api_user, 'User', params['id'].to_i)

          user = GogglesDb::User.find_by(id: params['id'])
          user&.update!(declared(params, include_missing: false))
        end
      end

      # DELETE /api/:version/user/:id
      #
      # Allows to delete a specific row given its ID.
      # Requires Admin grants for the requesting user.
      #
      # == Returns:
      # 'true' when successful; a +nil+ result (empty body) when not found.
      #
      desc 'Delete a User'
      params do
        requires :id, type: Integer, desc: 'User ID'
      end
      route_param :id do
        delete do
          reject_unless_authorized_admin(check_jwt_session)

          return unless GogglesDb::User.exists?(params['id'])

          error!(I18n.t('api.message.invalid_parameter'), 401, 'X-Error-Detail' => 'The first 4 users are required.') if params['id'].to_i < 5

          GogglesDb::User.destroy(params['id']).destroyed?
        end
      end
    end

    resource :users do
      # GET /api/:version/users
      #
      # Given some optional filtering parameters, returns the paginated list of users found.
      # (CRUD grant only)
      #
      # == Returns:
      # The list of Users for the specified filtering parameters as an array of JSON objects.
      # Finds the matching rows using a simple "LIKE %?%" on the specified parameters.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::User#to_json for structure details.
      #
      desc 'List Users'
      params do
        optional :name, type: String, desc: 'optional: User name'
        optional :first_name, type: String, desc: 'optional: first name'
        optional :last_name, type: String, desc: 'optional: last name'
        optional :description, type: String, desc: 'optional: User description - usually, first_name + blank + last_name'
        optional :email, type: String, desc: 'optional: email address'
        use :pagination
      end
      # Enforcing 'max_per_page' will add the allowed range to the swagger docs and
      # cause Grape to return an error when an out-of-range value is specified.
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate
      get do
        api_user = check_jwt_session
        reject_unless_authorized_for_crud(api_user, 'User')

        paginate GogglesDb::User.where(
          filtering_like_for(
            params,
            %w[name first_name last_name description email]
          )
        ).order('users.id DESC')
      end
    end
  end
end

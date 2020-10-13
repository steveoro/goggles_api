# frozen_string_literal: true

module Goggles
  # = Goggles API v3: User API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
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
          check_jwt_session

          GogglesDb::User.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/user/:id
      #
      # Allow direct update for most of the User fields.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update some User details'
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
          check_jwt_session

          user = GogglesDb::User.find_by_id(params['id'])
          user&.update!(declared(params, include_missing: false))
        end
      end
    end

    resource :users do
      # GET /api/:version/users
      #
      # Given some optional filtering parameters, returns the paginated list of users found.
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
      paginate
      get do
        check_jwt_session

        paginate GogglesDb::User.where(
          filtering_like_for(
            params,
            %w[name first_name last_name description email]
          )
        )
      end
    end
  end
end

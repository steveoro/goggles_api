# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Swimmer API Grape controller
  #
  #   - version:  1.07
  #   - author:   Steve A.
  #   - build:    20201006
  #
  class SwimmersAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :swimmer do
      # GET /api/:version/swimmer/:id
      #
      # == Returns:
      # The Swimmer instance matching the specified +id+ as JSON.
      # See GogglesDb::Swimmer#to_json for structure details.
      #
      desc 'Swimmer details'
      params do
        requires :id, type: Integer, desc: 'Swimmer ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::Swimmer.find_by_id(params['id'])
        end
      end

      # PUT /api/:version/swimmer/:id
      #
      # Allow direct update for most of the Swimmer fields.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update some Swimmer details'
      params do
        requires :id, type: Integer, desc: 'Swimmer ID'
        optional :first_name, type: String, desc: 'first name - filled only when actually known or obvious from the complete_name'
        optional :last_name, type: String, desc: 'last name - filled only when actually known or obvious from the complete_name'
        optional :complete_name, type: String, desc: 'complete name, as it appears from the public rankings'
        optional :nickname, type: String, desc: 'nickname'
        optional :year_of_birth, type: Integer, desc: 'year of birth - may be guessed or approximated'
        optional :associated_user_id, type: Integer, desc: 'associated User ID'
        optional :gender_type_id, type: Integer, desc: 'associated GenderType ID'
        optional :is_year_guessed, type: Boolean, desc: 'true when year of birth has been deduced from other data'
      end
      route_param :id do
        put do
          check_jwt_session

          swimmer = GogglesDb::Swimmer.find_by_id(params['id'])
          swimmer&.update!(declared(params, include_missing: false))
        end
      end
    end

    resource :swimmers do
      # GET /api/:version/swimmers
      #
      # Given some optional filtering parameters, returns the paginated list of swimmers found.
      #
      # == Returns:
      # The list of Swimmers for the specified filtering parameters as an array of JSON objects.
      # Returns exact matches for gender_type_id, year_of_birth, & is_year_guessed; supports partial matches
      # for the text name fields, but no fuzzy searches are performed here. (Use dedicated /search endpoints for that.)
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::Swimmer#to_json for structure details.
      #
      desc 'List Swimmers'
      params do
        optional :first_name, type: String, desc: 'optional: first name (partial match supported)'
        optional :last_name, type: String, desc: 'optional: last name (partial match supported)'
        optional :complete_name, type: String, desc: 'optional: complete name (partial match supported)'
        optional :gender_type_id, type: Integer, desc: 'optional: associated GenderType ID'
        optional :year_of_birth, type: Integer, desc: 'optional: year of birth'
        optional :is_year_guessed, type: Integer, desc: 'optional: true when year of birth has been deduced from other data'
        use :pagination
      end
      paginate
      get do
        check_jwt_session

        paginate GogglesDb::Swimmer.where(
          filtering_hash_for(params, %w[gender_type_id year_of_birth is_year_guessed])
        ).where(
          filtering_like_for(params, %w[first_name last_name complete_name])
        )
      end
    end
  end
end

# frozen_string_literal: true

module Goggles
  # = Goggles API v3: City API Grape controller
  #
  #   - version:  7.3.07
  #   - author:   Steve A.
  #   - build:    20210709
  #
  class CitiesAPI < Grape::API
    helpers APIHelpers

    format        :json
    content_type  :json, 'application/json'

    resource :city do
      # GET /api/:version/city/:id
      #
      # == Returns:
      # The City instance matching the specified +id+ as JSON.
      # See GogglesDb::City#to_json for structure details.
      #
      desc 'City details'
      params do
        requires :id, type: Integer, desc: 'City ID'
      end
      route_param :id do
        get do
          check_jwt_session

          GogglesDb::City.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/city/:id
      #
      # Allow direct update for most of the City fields.
      # Requires CRUD grant on entity ('City') for requesting user.
      #
      # == Returns:
      # 'true' when successful; an empty result when not found.
      #
      desc 'Update City details'
      params do
        requires :id, type: Integer, desc: 'City ID'
        optional :name, type: String, desc: 'optional: City name'
        optional :country_code, type: String, desc: 'optional: Country code (2 chars)'
        optional :country, type: String, desc: 'optional: Country name'
        optional :area, type: String, desc: 'optional: Area or Region/Division name'
        optional :zip, type: String, desc: 'optional: ZIP/CAP or Postal code override (max 6 chars)'
        optional :latitude, type: String, desc: 'optional: City latitude'
        optional :longitude, type: String, desc: 'optional: City longitude'
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, 'City')

          team_affiliation = GogglesDb::City.find_by(id: params['id'])
          team_affiliation&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/city
      # (ADMIN only)
      #
      # Creates a new City given the specified parameters.
      #
      # == Required Params:
      # * name: City name
      # * country_code: Country code (2 chars)
      # * country: Country name
      #
      # == Optional Params:
      # - area: Area or Region/Division name
      # - zip: IP/CAP or Postal code
      # - latitude: City latitude
      # - longitude: City longitude
      #
      # == Returns:
      # A JSON Hash containing the result 'msg' and the newly created instance:
      #
      #    { "msg": "OK", "new": { ...new row in JSON format... } }
      #
      desc 'Create a new City'
      params do
        requires :name, type: String, desc: 'City name'
        requires :country_code, type: String, desc: 'Country code (2 chars)'
        requires :country, type: String, desc: 'Country name'
        optional :area, type: String, desc: 'optional: Area or Region/Division name'
        optional :zip, type: String, desc: 'optional: ZIP/CAP or Postal code override'
        optional :latitude, type: String, desc: 'optional: City latitude'
        optional :longitude, type: String, desc: 'optional: City longitude'
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_admin(api_user)

        new_row = GogglesDb::City.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end

        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end
    end

    resource :cities do
      # GET /api/:version/cities
      #
      # Given some optional filtering parameters, returns the paginated list of City rows found.
      #
      # == Returns:
      # The list of Cities for the specified filtering parameters as an array of JSON objects.
      # Returns exact matches for the 'country_code' parametersd; supports partial matches
      # for the country name field plus a FULLTEXT search by the generic 'name' parameter on both
      # 'area' and 'name'.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See official API blueprint docs for more info.
      # See GogglesDb::City#to_json for structure details.
      #
      desc 'List Cities'
      params do
        optional :name, type: String, desc: 'optional: generic FULLTEXT search on name & area fields'
        optional :country_code, type: String, desc: 'optional: Country code (2 chars)'
        optional :country, type: String, desc: 'optional: Country name'
        use :pagination
      end
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate
      get do
        check_jwt_session

        paginate(
          filtering_fulltext_search_for(GogglesDb::City, params['name'])
            .where(filtering_hash_for(params, %w[country_code]))
            .where(filtering_like_for(params, %w[country]))
        )
      end

      # GET /api/:version/cities/search
      #
      # Search existing city names found inside the internal ISO3166::Country gem.
      #
      # == Returns:
      # The list of standardized string names as an array of JSON objects.
      # Returns exact matches for the 'country_code' parameters; supports fuzzy matches
      # for the City name.
      #
      # *Pagination* links are stored and returned in the response headers.
      # - 'Link': list of request links for last & next data pages, separated by ", "
      # - 'Total': total data rows found
      # - 'Per-Page': total rows per page
      # - 'Page': current page
      #
      # See CmdFindIsoCountry, CmdFindIsoCity & official API blueprint docs for more info.
      #
      desc 'Search ISO Cities with fuzzy search'
      params do
        requires :name, type: String, desc: 'City name'
        requires :country_code, type: String, desc: 'Country code (2 chars)'
        use :pagination
      end
      # Defaults:
      # paginate per_page: 25, max_per_page: nil, enforce_max_per_page: false
      paginate
      get :search do
        check_jwt_session

        country_finder = GogglesDb::CmdFindIsoCountry.call(nil, params['country_code'])
        city_finder = GogglesDb::CmdFindIsoCity.call(country_finder.result, params['name']) if country_finder.success?
        region_list = GogglesDb::IsoRegionList.new(params['country_code'])
        results = if city_finder.success?
                    city_finder.matches.map do |match_struct|
                      candidate = match_struct.candidate
                      {
                        'name' => candidate.name,
                        'population' => candidate.population,
                        'latitude' => candidate.latitude,
                        'longitude' => candidate.longitude,
                        'region_num' => candidate.region,
                        'region' => region_list.fetch(candidate.region)
                      }
                    end
                  else
                    []
                  end

        paginate results
      end
    end
  end
end

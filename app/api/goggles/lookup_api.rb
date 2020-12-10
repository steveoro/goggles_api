# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Swimmer API Grape controller
  #
  #   - version:  1.02
  #   - author:   Steve A.
  #   - build:    20201209
  #
  class LookupAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    resource :lookup do
      # GET /api/:version/lookup/:entity_name (plural)
      #
      # Returns the unfiltered list of all possible lookup values for a specific entity.
      #
      # == Params:
      # - entity_name: (required) plural name of the lookup entity
      # - locale: locale string code to be enforced (defaults to 'it')
      #
      # == Returns:
      # The JSON list of possible lookup values.
      # Returns an empty list on error or on invalid entity name. (Entities must be of the 'Localizable' kind.)
      #
      # *No* pagination is performed on the results (lookup entities are supposed to have limited rows).
      #
      # == Sample structure:
      #
      #     [
      #       { "id": 1, "code": "A", "label": "1st label", "long_label": "first label", "alt_label": "alt 1" },
      #       { "id": 2, "code": "B", "label": "2nd label", "long_label": "second label", "alt_label": "alt 2" },
      #       # ...
      #     ]
      #
      desc 'List lookup entity'
      params do
        requires :entity_name, type: String, desc: 'Entity name (plural)'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :entity_name do
        get do
          check_jwt_session

          entity = begin
            "GogglesDb::#{params['entity_name'].to_s.singularize.camelize}".constantize
          rescue NameError
            nil
          end
          return [] if entity.nil? || !entity&.new.is_a?(Localizable)

          entity.all.map { |row| row.lookup_attributes(params['locale'] || 'it') }
        end
      end
    end
  end
end

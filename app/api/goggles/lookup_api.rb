# frozen_string_literal: true

module Goggles
  # = Goggles API v3: Lookup API for all subentities
  #
  #   - version:  7.075
  #   - author:   Steve A.
  #   - build:    20210131
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
      # === Supported values for +entity_name+:
      # - `coach_level_types`
      # - `day_part_types`
      # - `disqualification_code_types`
      # - `edition_types`
      # - `entry_time_types`
      # - `event_types`
      # - `hair_dryer_types`
      # - `heat_types`
      # - `locker_cabinet_types`
      # - `medal_types`
      # - `pool_types`
      # - `record_types`
      # - `shower_types`
      # - `stroke_types`
      # - `swimmer_level_types`
      # - `timing_types`
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

          entity = lookup_entity_class_for(params['entity_name'].to_s)
          return [] if entity.nil? || !entity&.new.is_a?(Localizable)

          entity.all.map { |row| row.lookup_attributes(params['locale'] || 'it') }
        end
      end
    end
  end
end

# frozen_string_literal: true

module Goggles
  module Entities
    # Entity for SwimmingPool endpoints.
    class SwimmingPoolEntity < BaseEntity
      expose :id, documentation: { type: 'Integer', desc: 'SwimmingPool ID' }
      expose :name, documentation: { type: 'String', desc: 'Official name' }
      expose :nick_name, documentation: { type: 'String', desc: 'Short name or nick-name' }
      expose :address, documentation: { type: 'String', desc: 'Address' }
      expose :zip, documentation: { type: 'String', desc: 'Zip code' }
      expose :phone_number, documentation: { type: 'String', desc: 'Phone number' }
      expose :fax_number, documentation: { type: 'String', desc: 'Fax number' }
      expose :e_mail, documentation: { type: 'String', desc: 'E-mail address' }
      expose :contact_name, documentation: { type: 'String', desc: 'Contact name' }
      expose :maps_uri, documentation: { type: 'String', desc: 'Online map URI' }
      expose :lanes_number, documentation: { type: 'Integer', desc: 'Total number of pool lanes' }
      expose :multiple_pools, documentation: { type: 'Boolean', desc: 'True: has more than 1 pool' }
      expose :garden, documentation: { type: 'Boolean', desc: 'True: has a garden area or solarium' }
      expose :bar, documentation: { type: 'Boolean', desc: 'True: includes an internal Bar' }
      expose :restaurant, documentation: { type: 'Boolean', desc: 'True: includes an internal Restaurant' }
      expose :gym, documentation: { type: 'Boolean', desc: 'True: includes an internal Gym area' }
      expose :child_area, documentation: { type: 'Boolean', desc: 'True: includes a dedicated Children Area' }
      expose :notes, documentation: { type: 'String', desc: 'Additional notes' }
      expose :city_id, documentation: { type: 'Integer', desc: 'Associated City ID' }
      expose :pool_type_id, documentation: { type: 'Integer', desc: 'Associated PoolType ID' }
      expose :shower_type_id, documentation: { type: 'Integer', desc: 'Associated ShowerType ID' }
      expose :hair_dryer_type_id, documentation: { type: 'Integer', desc: 'Associated HairDryerType ID' }
      expose :locker_cabinet_type_id, documentation: { type: 'Integer', desc: 'Associated LockerCabinetType ID' }
      expose :read_only, documentation: { type: 'Boolean', desc: 'True: disable any further updates' }
      expose :latitude, documentation: { type: 'Float', desc: 'Latitude' }
      expose :longitude, documentation: { type: 'Float', desc: 'Longitude' }
      expose :plus_code, documentation: { type: 'String', desc: 'Google Plus Code' }
      expose :created_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Creation timestamp (ISO8601)' }
      expose :updated_at, format_with: :iso_timestamp,
                          documentation: { type: 'String', desc: 'Last update timestamp (ISO8601)' }
    end
  end
end

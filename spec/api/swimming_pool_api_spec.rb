# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SwimmingPoolsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_swimming_pool) { FactoryBot.create(:swimming_pool) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_swimming_pool).to be_a(GogglesDb::SwimmingPool).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/swimming_pool/:id' do
    context 'when using valid parameters,' do
      before(:each) do
        get api_v3_swimming_pool_path(id: fixture_swimming_pool.id), headers: fixture_headers
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_swimming_pool.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get api_v3_swimming_pool_path(id: fixture_swimming_pool.id), headers: { 'Authorization' => 'you wish!' }
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        get api_v3_swimming_pool_path(id: -1), headers: fixture_headers
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/swimming_pool/:id' do
    let(:crud_user) { FactoryBot.create(:user) }
    let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'SwimmingPool') }
    let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters' do
      let(:associated_user) { FactoryBot.create(:user) }
      let(:expected_changes) do
        # optional :read_only, type: Boolean, desc: 'true: disable any further updates'
        [
          {
            name: "#{FFaker::Address.street_name} pool",
            address: FFaker::Address.street_address,
            nick_name: FFaker::Address.street_name.downcase.gsub(' ', '')
          },
          { contact_name: FFaker::Name.name, phone_number: FFaker::Name.first_name, e_mail: FFaker::Internet.safe_email },
          { pool_type_id: GogglesDb::PoolType.all_eventable.sample.id },
          { city_id: GogglesDb::City.limit(50).select(:id).sample.id, maps_uri: "#{FFaker::Internet.uri('https')}?q=whatever" },
          {
            multiple_pools: FFaker::Boolean.random, garden: FFaker::Boolean.random, bar: FFaker::Boolean.random,
            restaurant: FFaker::Boolean.random, gym: FFaker::Boolean.random, child_area: FFaker::Boolean.random
          },
          {
            shower_type_id: GogglesDb::ShowerType.all.select(:id).sample.id,
            hair_dryer_type_id: GogglesDb::HairDryerType.all.select(:id).sample.id,
            locker_cabinet_type_id: GogglesDb::LockerCabinetType.all.select(:id).sample.id
          },
          { notes: FFaker::Lorem.sentence }
        ].sample
      end
      before(:each) { expect(expected_changes).to be_an(Hash) }

      context 'with an account having CRUD grants,' do
        before(:each) do
          put(api_v3_swimming_pool_path(id: fixture_swimming_pool.id), params: expected_changes, headers: crud_headers)
        end
        it 'is successful' do
          expect(response).to be_successful
        end
        it 'updates the row and returns true' do
          expect(response.body).to eq('true')
          updated_row = fixture_swimming_pool.reload
          expected_changes.each do |key, _value|
            expect(updated_row.send(key)).to eq(expected_changes[key])
          end
        end
      end

      context 'and editing the read_only attribute' do
        context 'with an account having ADMIN grants,' do
          let(:admin_user) { FactoryBot.create(:user) }
          let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
          let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
          let(:fixture_pool_2) { FactoryBot.create(:swimming_pool, read_only: false) }
          before(:each) do
            expect(fixture_pool_2).to be_a(GogglesDb::SwimmingPool).and be_valid
            expect(admin_user).to be_a(GogglesDb::User).and be_valid
            expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
            expect(admin_headers).to be_an(Hash).and have_key('Authorization')
          end
          before(:each) do
            put(api_v3_swimming_pool_path(id: fixture_pool_2.id), params: { read_only: true }, headers: admin_headers)
          end
          it 'is successful' do
            expect(response).to be_successful
          end
          it 'updates the row and returns true' do
            expect(response.body).to eq('true')
            updated_row = fixture_pool_2.reload
            expect(updated_row.read_only).to be true
          end
        end

        context 'with an account having just CRUD grants,' do
          before(:each) do
            put(api_v3_swimming_pool_path(id: fixture_swimming_pool.id), params: { read_only: true }, headers: crud_headers)
          end
          it_behaves_like 'an empty but successful JSON response'
        end
      end

      context 'with an account not having the proper grants,' do
        before(:each) do
          put(api_v3_swimming_pool_path(id: fixture_swimming_pool.id), params: expected_changes, headers: fixture_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_swimming_pool_path(id: fixture_swimming_pool.id),
          params: { pool_type_id: GogglesDb::PoolType::MT_25_ID },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_swimming_pool_path(id: -1),
          params: { pool_type_id: GogglesDb::PoolType::MT_25_ID },
          headers: crud_headers
        )
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/swimming_pools/' do
    context 'when using a valid authentication' do
      let(:fixture_pool_type_id) { GogglesDb::PoolType.all_eventable.sample.id }
      let(:default_per_page) { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) { expect(fixture_pool_type_id).to be_positive }

      context 'without any filters,' do
        before(:each) do
          get(api_v3_swimming_pools_path, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to eq(default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      context 'filtering by a specific pool_type_id,' do
        before(:each) do
          get(api_v3_swimming_pools_path, params: { pool_type_id: fixture_pool_type_id }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::SwimmingPool.where(pool_type_id: fixture_pool_type_id).count
          expect(result_array.count).to eq(full_count <= default_per_page ? full_count : default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      # Uses random fixtures, to have a quick 1-row result (no pagination, always):
      context 'filtering by a specific address of a random single fixture,' do
        before(:each) do
          get(
            api_v3_swimming_pools_path,
            params: { name: fixture_swimming_pool.name, address: fixture_swimming_pool.address },
            headers: fixture_headers
          )
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_swimming_pool].to_json)
        end
        it_behaves_like 'single response without pagination links in headers'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get(api_v3_swimming_pools_path, headers: { 'Authorization' => 'you wish!' })
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) do
        get(api_v3_swimming_pools_path, params: { pool_type_id: -1 }, headers: fixture_headers)
      end
      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end

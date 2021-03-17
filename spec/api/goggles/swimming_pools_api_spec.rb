# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SwimmingPoolsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:swimming_pool) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }
  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'SwimmingPool') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::SwimmingPool).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(crud_user).to be_a(GogglesDb::User).and be_valid
    expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(crud_headers).to be_an(Hash).and have_key('Authorization')
  end

  describe 'GET /api/v3/swimming_pool/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_swimming_pool_path(id: fixture_row.id), headers: fixture_headers) }
      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before(:each) do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_swimming_pool_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end
      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_swimming_pool_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_swimming_pool_path(id: -1), headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/swimming_pool/:id' do
    context 'when using valid parameters' do
      let(:associated_user) { FactoryBot.create(:user) }
      let(:expected_changes) do
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
        before(:each) { put(api_v3_swimming_pool_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }
        it_behaves_like('a successful JSON PUT response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_swimming_pool_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      # Admin-only fields update check:
      context 'and editing the read_only attribute' do
        context 'with an account having ADMIN grants,' do
          let(:fixture_pool2) { FactoryBot.create(:swimming_pool, read_only: false) }
          before(:each) do
            expect(fixture_pool2).to be_a(GogglesDb::SwimmingPool).and be_valid
            expect(admin_user).to be_a(GogglesDb::User).and be_valid
            expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
            expect(admin_headers).to be_an(Hash).and have_key('Authorization')
          end
          before(:each) { put(api_v3_swimming_pool_path(id: fixture_pool2.id), params: { read_only: true }, headers: admin_headers) }

          it_behaves_like('a successful request that has positive usage stats')

          it 'updates the row and returns true' do
            expect(response.body).to eq('true')
            updated_row = fixture_pool2.reload
            expect(updated_row.read_only).to be true
          end
        end

        context 'with an account having just CRUD grants,' do
          before(:each) { put(api_v3_swimming_pool_path(id: fixture_row.id), params: { read_only: true }, headers: crud_headers) }
          it_behaves_like('an empty but successful JSON response')
        end
      end

      context 'with an account not having the proper grants,' do
        before(:each) { put(api_v3_swimming_pool_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_swimming_pool_path(id: fixture_row.id),
          params: { pool_type_id: GogglesDb::PoolType::MT_25_ID },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_swimming_pool_path(id: -1),
          params: { pool_type_id: GogglesDb::PoolType::MT_25_ID },
          headers: crud_headers
        )
      end
      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/swimming_pool' do
    let(:built_row) { FactoryBot.build(:swimming_pool, city: GogglesDb::City.limit(50).sample) }
    before(:each) do
      expect(admin_user).to be_a(GogglesDb::User).and be_valid
      expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(admin_headers).to be_an(Hash).and have_key('Authorization')
      expect(built_row).to be_a(GogglesDb::SwimmingPool).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) { post(api_v3_swimming_pool_path, params: built_row.attributes, headers: admin_headers) }
        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before(:each) { post(api_v3_swimming_pool_path, params: built_row.attributes, headers: crud_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      context 'with an account not having any grants,' do
        before(:each) { post(api_v3_swimming_pool_path, params: built_row.attributes, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { post(api_v3_swimming_pool_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using invalid parameters,' do
      before(:each) { post(api_v3_swimming_pool_path, params: built_row.attributes.merge(pool_type_id: -1), headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.creation_failure'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to be_present
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/swimming_pools/' do
    context 'when using a valid authentication' do
      let(:fixture_row) { GogglesDb::SwimmingPool.where('(address IS NOT NULL) AND (address != \'\')').limit(50).sample }
      let(:fixture_pool_type_id) { fixture_row.pool_type_id }
      let(:default_per_page) { 25 }
      # Make sure the Domain contains the expected seeds:
      before(:each) do
        expect(fixture_row).to be_a(GogglesDb::SwimmingPool).and be_valid
        expect(fixture_pool_type_id).to be_positive
      end

      context 'without any filters,' do
        before(:each) { get(api_v3_swimming_pools_path, headers: fixture_headers) }
        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'but during Maintenance mode,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_swimming_pools_path, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific pool_type_id,' do
        before(:each) { get(api_v3_swimming_pools_path, params: { pool_type_id: fixture_pool_type_id }, headers: fixture_headers) }
        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when filtering by a generic name search term,' do
        let(:search_term) { fixture_row.name.split.first }
        let(:expected_row_count) { GogglesDb::SwimmingPool.for_name(search_term).count }
        before(:each) { get(api_v3_swimming_pools_path, params: { name: search_term }, headers: fixture_headers) }

        # [Steve, 20210111]
        # We cannot assert the inclusion of the fixture_row.id inside the returned_ids
        # because of pagination (the expected ID could be shown in a follow-up page).
        # So, this cannot be tested: (yields random failures)
        #
        # it 'returns a JSON array including the existing row' do
        #   returned_ids = JSON.parse(response.body).map { |row| row['id'] }
        #   expect(returned_ids).to include(fixture_row.id)
        # end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific name & address of an existing data row,' do
        let(:expected_row_count) do
          GogglesDb::SwimmingPool.for_name(fixture_row.name)
                                 .where(city_id: fixture_row.city_id)
                                 .where(
                                   ActiveRecord::Base.sanitize_sql_for_conditions(
                                     "address like '%#{fixture_row.address}%'"
                                   )
                                 )
                                 .count
        end
        before(:each) do
          get(
            api_v3_swimming_pools_path,
            params: { name: fixture_row.name, city_id: fixture_row.city_id, address: fixture_row.address },
            headers: fixture_headers
          )
        end
        # Several cities have more than 1 pool at the same address, with also similar name and just an
        # added prefix ('Comunale'), so a single row result here is not guaranteed:
        it 'returns a JSON array including the existing row' do
          returned_ids = JSON.parse(response.body).map { |row| row['id'] }
          expect(returned_ids).to include(fixture_row.id)
        end
        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when enabling custom Select2 output,' do
        let(:search_term) { fixture_row.name.split.first }
        let(:expected_row_count) { GogglesDb::SwimmingPool.for_name(search_term).limit(100).count }
        before(:each) { get(api_v3_swimming_pools_path, params: { name: search_term, select2_format: true }, headers: fixture_headers) }
        it_behaves_like('successful response in Select2 bespoke format')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_swimming_pools_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_swimming_pools_path, params: { pool_type_id: -1 }, headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end

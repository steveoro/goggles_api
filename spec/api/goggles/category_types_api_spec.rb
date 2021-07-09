# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::CategoryTypesAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:category_type) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'CategoryType') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_row).to be_a(GogglesDb::CategoryType).and be_valid
    expect(admin_user).to be_a(GogglesDb::User).and be_valid
    expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(admin_headers).to be_an(Hash).and have_key('Authorization')
    expect(crud_user).to be_a(GogglesDb::User).and be_valid
    expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(fixture_headers).to be_an(Hash).and have_key('Authorization')
  end

  describe 'GET /api/v3/category_type/:id' do
    context 'when using valid parameters,' do
      before(:each) { get(api_v3_category_type_path(id: fixture_row.id), headers: fixture_headers) }
      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_category_type_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a successful JSON row response')
      end
      context 'with an account having lesser grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_category_type_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get api_v3_category_type_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end
    context 'when requesting a non-existing ID,' do
      before(:each) { get(api_v3_category_type_path(id: -1), headers: fixture_headers) }
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/category_type/:id' do
    let(:built_row) { FactoryBot.build(:category_type, season_id: FactoryBot.create('season').id) }
    let(:expected_changes) do
      [
        { age_begin: built_row.age_begin },
        { age_end: built_row.age_end },
        { description: built_row.description },
        { short_name: built_row.short_name },
        { federation_code: built_row.federation_code },
        { relay: [true, false].sample },
        { out_of_race: [true, false].sample },
        { undivided: [true, false].sample }
      ].sample
    end
    before(:each) do
      expect(built_row).to be_a(GogglesDb::CategoryType).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end
    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) { put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }
        it_behaves_like('a successful JSON PUT response')
      end
      context 'with an account having just CRUD grants,' do
        before(:each) { put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
      context 'with an account not having any grants,' do
        before(:each) { put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a successful JSON PUT response')
      end
      context 'with an account having lesser grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end
    context 'when requesting a non-existing ID,' do
      before(:each) { put(api_v3_category_type_path(id: -1), params: expected_changes, headers: admin_headers) }
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/category_type' do
    # Make sure parameters for the POST include all required attributes:
    let(:built_row) { FactoryBot.build(:category_type, season_id: FactoryBot.create('season').id) }
    before(:each) do
      expect(built_row).to be_a(GogglesDb::CategoryType).and be_valid
    end
    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) { post(api_v3_category_type_path, params: built_row.attributes, headers: admin_headers) }
        it_behaves_like('a successful JSON POST response')
      end
      context 'with an account having just CRUD grants,' do
        before(:each) { post(api_v3_category_type_path, params: built_row.attributes, headers: crud_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
      context 'with an account not having any grants,' do
        before(:each) { post(api_v3_category_type_path, params: built_row.attributes, headers: fixture_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_category_type_path, params: built_row.attributes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a successful JSON POST response')
      end
      context 'with an account having lesser grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_category_type_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { post(api_v3_category_type_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before(:each) do
        post(
          api_v3_category_type_path,
          params: {
            code: 'NOPE',
            season_id: -1,
            short_name: built_row.short_name,
            group_name: built_row.group_name,
            age_begin: built_row.age_begin,
            age_end: built_row.age_end
          },
          headers: admin_headers
        )
      end

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

  describe 'DELETE /api/v3/category_type/:id' do
    let(:deletable_row) { FactoryBot.create(:category_type) }
    before(:each) { expect(deletable_row).to be_a(GogglesDb::CategoryType).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) { delete(api_v3_category_type_path(id: deletable_row.id), headers: admin_headers) }
        it_behaves_like('a successful JSON DELETE response')
      end
      context 'with an account having just CRUD grants,' do
        before(:each) { delete(api_v3_category_type_path(id: deletable_row.id), headers: crud_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
      context 'with an account not having any grants,' do
        before(:each) { delete(api_v3_category_type_path(id: deletable_row.id), headers: fixture_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_category_type_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a successful JSON DELETE response')
      end
      context 'with an account having lesser grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_category_type_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { delete(api_v3_category_type_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end
    context 'when requesting a non-existing ID,' do
      before(:each) { delete(api_v3_category_type_path(id: -1), headers: admin_headers) }
      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/category_types/' do
    let(:fixture_season_id) { [152, 162, 172, 182, 192].sample }
    let(:fixture_code) { %w[M25 M30 M35 M40 M50 M55].sample }
    let(:default_per_page) { 25 }
    let(:expected_row_count) { GogglesDb::CategoryType.where(code: fixture_code).count }
    # Enforce Domain existance:
    before(:each) do
      expect(fixture_season_id).to be_positive
      expect(fixture_code).to be_a(String).and be_present
      expect(expected_row_count).to be_positive
    end

    context 'without any filters (with valid authentication),' do
      before(:each) { get(api_v3_category_types_path, headers: fixture_headers) }
      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'without any filters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_category_types_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('successful response with pagination links & values in headers')
      end
      context 'with an account having lesser grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_category_types_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when filtering by a specific season_id (with valid authentication),' do
      before(:each) { get(api_v3_category_types_path, params: { code: fixture_code }, headers: fixture_headers) }
      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when enabling custom Select2 output (with valid authentication),' do
      before(:each) do
        expect(expected_row_count).to be_positive
        get(api_v3_category_types_path, params: { code: fixture_code, select2_format: true }, headers: fixture_headers)
      end
      it_behaves_like('successful response in Select2 bespoke format')
    end

    context 'when filtering by a specific code (with valid authentication),' do
      before(:each) { get(api_v3_category_types_path, params: { season_id: fixture_season_id }, headers: fixture_headers) }
      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_category_types_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end
    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_category_types_path, params: { season_id: -1 }, headers: fixture_headers) }
      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end

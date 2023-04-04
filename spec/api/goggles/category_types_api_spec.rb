# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::CategoryTypesAPI do
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
  before do
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
      before { get(api_v3_category_type_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_category_type_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_category_type_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_category_type_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_category_type_path(id: -1), headers: fixture_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/category_type/:id' do
    let(:built_row) { FactoryBot.build(:category_type, season_id: FactoryBot.create(:season).id) }
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

    before do
      expect(built_row).to be_a(GogglesDb::CategoryType).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having just CRUD grants,' do
        before { put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_category_type_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_category_type_path(id: -1), params: expected_changes, headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/category_type' do
    # Make sure parameters for the POST include all required attributes:
    let(:built_row) { FactoryBot.build(:category_type, season_id: FactoryBot.create(:season).id) }

    before do
      expect(built_row).to be_a(GogglesDb::CategoryType).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_category_type_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_category_type_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_category_type_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_category_type_path, params: built_row.attributes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_category_type_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_category_type_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before do
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

    before { expect(deletable_row).to be_a(GogglesDb::CategoryType).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_category_type_path(id: deletable_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_category_type_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_category_type_path(id: deletable_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_category_type_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_category_type_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_category_type_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_category_type_path(id: -1), headers: admin_headers) }

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

    before do
      expect(fixture_season_id).to be_positive
      expect(fixture_code).to be_a(String).and be_present
      expect(expected_row_count).to be_positive
    end

    context 'without any filters (with valid authentication),' do
      before { get(api_v3_category_types_path, headers: fixture_headers) }

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'without any filters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_category_types_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_category_types_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when filtering by a specific code (with valid authentication),' do
      before { get(api_v3_category_types_path, params: { code: fixture_code }, headers: fixture_headers) }

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when enabling custom Select2 output (with valid authentication),' do
      before do
        expect(expected_row_count).to be_positive
        get(api_v3_category_types_path, params: { code: fixture_code, select2_format: true }, headers: fixture_headers)
      end

      it_behaves_like('successful response in Select2 bespoke format')
    end

    context 'when filtering by a specific season_id (with valid authentication),' do
      before { get(api_v3_category_types_path, params: { season_id: fixture_season_id }, headers: fixture_headers) }

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_category_types_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_category_types_path, params: { season_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/category_type/clone' do
    let(:src_season_id) { [152, 162, 172, 182, 192].sample }
    let(:dest_season_id) { FactoryBot.create(:season).id }
    let(:valid_params) { { from_season_id: src_season_id, to_season_id: dest_season_id } }

    before do
      expect(dest_season_id).to be_positive
      expect(valid_params).to be_an(Hash).and be_present
      expect(GogglesDb::Season.exists?(src_season_id)).to be true
      expect(GogglesDb::Season.exists?(dest_season_id)).to be true
      expect(GogglesDb::Season.find(dest_season_id).category_types.count).to be_zero
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_category_types_clone_path, params: valid_params, headers: admin_headers) }

        it_behaves_like('a successful request that has positive usage stats')
        it 'returns an OK message and the new row as a JSON object' do
          result = JSON.parse(response.body)
          expect(result).to have_key('msg')
          expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
        end
        # Side-effect (checked because we're not adding any integration tests for this one):

        it 'adds the catories to the destination season' do
          scr_count = GogglesDb::Season.find(src_season_id).category_types.count
          dest_count = GogglesDb::Season.find(dest_season_id).category_types.count
          expect(dest_count).to be >= scr_count
        end
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_category_types_clone_path, params: valid_params, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_category_types_clone_path, params: valid_params, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_category_types_clone_path, params: valid_params, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful request that has positive usage stats')
        it 'returns an OK message and the new row as a JSON object' do
          result = JSON.parse(response.body)
          expect(result).to have_key('msg')
          expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
        end
        # Side-effect (checked because we're not adding any integration tests for this one):

        it 'adds the catories to the destination season' do
          scr_count = GogglesDb::Season.find(src_season_id).category_types.count
          dest_count = GogglesDb::Season.find(dest_season_id).category_types.count
          expect(dest_count).to be >= scr_count
        end
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_category_types_clone_path, params: valid_params, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_category_types_clone_path, params: valid_params, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before do
        post(
          api_v3_category_types_clone_path,
          params: { from_season_id: src_season_id, to_season_id: -1 },
          headers: admin_headers
        )
      end

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.invalid_parameter'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to be_present
      end
    end

    context 'when using valid but equal parameters (src == dest),' do
      before do
        post(
          api_v3_category_types_clone_path,
          params: { from_season_id: src_season_id, to_season_id: src_season_id },
          headers: admin_headers
        )
      end

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.invalid_parameter'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to eq('source ID = destination ID')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end

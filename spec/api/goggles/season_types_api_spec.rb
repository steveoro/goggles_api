# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SeasonTypesAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { GogglesDb::SeasonType.all.sample }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'SeasonType') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::SeasonType).and be_valid
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

  describe 'GET /api/v3/season_type/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_season_type_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_season_type_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_season_type_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_season_type_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_season_type_path(id: -1), headers: fixture_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/season_type/:id' do
    let(:built_row) do
      federation_type = GogglesDb::FederationType.all.sample
      unique_code = GogglesDb::SeasonType.last.id + 1
      GogglesDb::SeasonType.new(
        code: format('%<fedcode>s-%<val>03d', fedcode: federation_type.code, val: unique_code),
        federation_type_id: federation_type.id,
        short_name: "Fake #{federation_type.code} Season #{unique_code}",
        description: "Fake #{federation_type.code} Season #{unique_code}"
      )
    end
    let(:expected_changes) do
      [
        { code: built_row.code },
        { federation_type_id: built_row.federation_type_id },
        { short_name: built_row.short_name },
        { description: built_row.description }
      ].sample
    end

    before do
      expect(built_row).to be_a(GogglesDb::SeasonType).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_season_type_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having just CRUD grants,' do
        before { put(api_v3_season_type_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_season_type_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_season_type_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_season_type_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_season_type_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_season_type_path(id: -1), params: expected_changes, headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/season_type' do
    let(:built_row) do
      federation_type = GogglesDb::FederationType.all.sample
      unique_code = GogglesDb::SeasonType.last.id + 1
      GogglesDb::SeasonType.new(
        code: format('%<fedcode>s-%<val>03d', fedcode: federation_type.code, val: unique_code),
        federation_type_id: federation_type.id,
        short_name: "Fake #{federation_type.code} Season #{unique_code}",
        description: "Fake #{federation_type.code} Season #{unique_code}"
      )
    end

    before do
      expect(built_row).to be_a(GogglesDb::SeasonType).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_season_type_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_season_type_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_season_type_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_season_type_path, params: built_row.attributes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_season_type_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_season_type_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before do
        post(
          api_v3_season_type_path,
          params: {
            code: '',
            federation_type_id: built_row.federation_type_id,
            short_name: built_row.short_name,
            description: built_row.description
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

  describe 'GET /api/v3/season_types/' do
    let(:fixture_code) { %w[fin csi].sample }
    let(:default_per_page) { 25 }

    context 'without any filters (with valid authentication),' do
      let(:expected_row_count) { GogglesDb::SeasonType.count }

      before do
        expect(expected_row_count).to be_positive
        get(api_v3_season_types_path, headers: fixture_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'without any filters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        let(:expected_row_count) { GogglesDb::SeasonType.count }

        before do
          expect(expected_row_count).to be_positive
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_season_types_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_season_types_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    %w[code short_name].each do |filter_name|
      context "when filtering by #{filter_name} (with valid authentication)," do
        let(:expected_row_count) { GogglesDb::SeasonType.where("#{filter_name} LIKE ?", "%#{fixture_code}%").count }

        before do
          expect(fixture_code).to be_a(String).and be_present
          expect(expected_row_count).to be_positive
          get(api_v3_season_types_path, params: { filter_name => fixture_code }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end
    end

    context 'when filtering by description (with valid authentication),' do
      let(:expected_row_count) { GogglesDb::SeasonType.where('description LIKE ?', '%master%').count }

      before do
        expect(fixture_code).to be_a(String).and be_present
        expect(expected_row_count).to be_positive
        get(api_v3_season_types_path, params: { description: 'master' }, headers: fixture_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by a specific federation_type_id (with valid authentication),' do
      let(:fixture_federation_type_id) { GogglesDb::SeasonType.all.map(&:federation_type_id).uniq.sample }
      let(:expected_row_count) { GogglesDb::SeasonType.where(federation_type_id: fixture_federation_type_id).count }

      before do
        expect(fixture_federation_type_id).to be_positive
        expect(expected_row_count).to be_positive
        get(api_v3_season_types_path, params: { federation_type_id: fixture_federation_type_id }, headers: fixture_headers)
      end

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_season_types_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_season_types_path, params: { federation_type_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end

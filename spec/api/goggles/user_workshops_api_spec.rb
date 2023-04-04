# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::UserWorkshopsAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:user_workshop) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'UserWorkshop') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::UserWorkshop).and be_valid
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

  describe 'GET /api/v3/user_workshop/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_user_workshop_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_user_workshop_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_user_workshop_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_user_workshop_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/user_workshop/:id' do
    let(:fixture_code) { "#{FFaker::Address.city.downcase}-user_workshop-#{(rand * 10_000).to_i}" }

    context 'when using valid parameters,' do
      let(:new_date) { fixture_row.season.begin_date + (rand * 100).to_i.days }
      let(:expected_changes) do
        [
          { code: fixture_code, header_date: new_date, description: FFaker::Lorem.sentence[0..90] },
          { code: fixture_code, timing_type_id: GogglesDb::TimingType.send(%w[manual semiauto automatic].sample).id },
          { edition_type_id: GogglesDb::EditionType.send(%w[ordinal roman none yearly seasonal].sample).id, edition: (rand * 20).to_i },
          { confirmed: [false, true].sample, pb_acquired: [false, true].sample, cancelled: [false, true].sample }
        ].sample
      end

      before do
        expect(fixture_code).to be_a(String).and be_present
        expect(expected_changes).to be_an(Hash)
      end

      context 'with an account having CRUD grants,' do
        before { put(api_v3_user_workshop_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'and ADMIN grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_user_workshop_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'and lesser grants during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_user_workshop_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      # Admin-only fields update test:
      [
        { season_id: FactoryBot.create(:season).id },
        { read_only: [true, false].sample }
      ].each do |admin_changes|
        context "when editing the #{admin_changes.keys.first} attribute" do
          let(:fixture_row2) { FactoryBot.create(:user_workshop) }

          before { expect(fixture_row2).to be_a(GogglesDb::UserWorkshop).and be_valid }

          context 'with an account having ADMIN grants,' do
            before do
              put(api_v3_user_workshop_path(id: fixture_row2.id), params: admin_changes, headers: admin_headers)
            end

            it_behaves_like('a successful request that has positive usage stats')
            it 'updates the row and returns true' do
              expect(response.body).to eq('true')
              updated_row = fixture_row2.reload
              expect(updated_row.send(admin_changes.keys.first) == admin_changes.values.first).to be true
            end
          end

          context 'with an account having just CRUD grants,' do
            before { put(api_v3_user_workshop_path(id: fixture_row2.id), params: admin_changes, headers: crud_headers) }

            it_behaves_like('an empty but successful JSON response')
          end
        end
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_user_workshop_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_user_workshop_path(id: fixture_row.id), params: { code: fixture_code }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_user_workshop_path(id: -1), params: { code: fixture_code }, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/user_workshop' do
    # Make sure parameters for the POST include all required attributes:
    let(:built_row) do
      FactoryBot.build(
        :user_workshop,
        user_id: GogglesDb::User.first(50).sample.id,
        season_id: GogglesDb::Season.last(15).sample.id,
        team_id: GogglesDb::Team.first(50).sample.id,
        edition_type_id: GogglesDb::EditionType::ORDINAL_ID,
        timing_type_id: GogglesDb::TimingType::MANUAL_ID
      )
    end

    before do
      expect(built_row).to be_a(GogglesDb::UserWorkshop).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_user_workshop_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_user_workshop_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_user_workshop_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_user_workshop_path, params: built_row.attributes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_user_workshop_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_user_workshop_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before do
        post(
          api_v3_user_workshop_path,
          params: built_row.attributes.merge(season_id: -1),
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

  describe 'DELETE /api/v3/user_workshop/:id' do
    let(:deletable_row) { FactoryBot.create(:user_workshop) }

    before { expect(deletable_row).to be_a(GogglesDb::UserWorkshop).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_user_workshop_path(id: deletable_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_user_workshop_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_user_workshop_path(id: deletable_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_user_workshop_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_user_workshop_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_user_workshop_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_user_workshop_path(id: -1), headers: admin_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/user_workshops/' do
    # Add some fixtures to the test Domain once:
    before(:all) do
      @fixture_user_id = FactoryBot.create(:user).id
      @fixture_team_id = GogglesDb::Team.first(50).sample.id
      FactoryBot.create_list(:user_workshop, 5, user_id: @fixture_user_id)
      FactoryBot.create_list(:user_workshop, 26, team_id: @fixture_team_id)
    end

    after(:all) do
      GogglesDb::UserWorkshop.where(user_id: @fixture_user_id).delete_all
      GogglesDb::UserWorkshop.where(team_id: @fixture_team_id).delete_all
    end

    let(:default_per_page) { 25 }
    # Make sure the Domain contains the expected seeds:

    before { expect(GogglesDb::UserWorkshop.count).to be >= 31 }

    context 'when using valid authentication' do
      let(:fixture_description) { workshops_in_domain.sample.description }
      let(:workshops_in_domain) { GogglesDb::UserWorkshop.all.limit(50) }

      context 'without any filters,' do
        before { get(api_v3_user_workshops_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'during Maintenance mode with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_workshops_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'during Maintenance mode with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_workshops_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'and filtering by a specific team (yielding > 25 rows),' do
        let(:expected_row_count) { GogglesDb::UserWorkshop.where(team_id: @fixture_team_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_user_workshops_path, params: { team_id: @fixture_team_id }, headers: fixture_headers)
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'and filtering by a specific user (yielding <= 25 rows),' do
        let(:expected_row_count) { GogglesDb::UserWorkshop.where(user_id: @fixture_user_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_user_workshops_path, params: { user_id: @fixture_user_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'and filtering by a specific date,' do
        let(:sample_date) { workshops_in_domain.sample.header_date }
        let(:expected_row_count) { workshops_in_domain.where(header_date: sample_date).distinct.count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_user_workshops_path, params: { date: sample_date }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'and filtering by name,' do
        let(:expected_row_count) { GogglesDb::UserWorkshop.for_name(fixture_description).distinct.count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_user_workshops_path, params: { name: fixture_description }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'and enabling custom Select2 output,' do
        let(:expected_row_count) { GogglesDb::UserWorkshop.for_name(fixture_description).distinct.limit(100).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_user_workshops_path, params: { name: fixture_description, select2_format: true }, headers: fixture_headers)
        end

        it_behaves_like('successful response in Select2 bespoke format')
      end
    end

    context 'with an invalid JWT,' do
      before { get(api_v3_user_workshops_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'and filtering by a non-existing value,' do
      before { get(api_v3_user_workshops_path, params: { date: '1986-01-01' }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end

# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::MeetingsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:meeting) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Meeting') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::Meeting).and be_valid
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

  describe 'GET /api/v3/meeting/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_meeting_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_meeting_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_meeting_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_meeting_path(id: -1), headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/meeting/:id' do
    let(:fixture_code) { "#{FFaker::Address.city.downcase}-meeting-#{(rand * 10_000).to_i}" }
    let(:crud_user) { FactoryBot.create(:user) }
    let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Meeting') }
    let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

    before do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      let(:new_date) { fixture_row.season.begin_date + (rand * 100).to_i.days }
      let(:expected_changes) do
        [
          { code: fixture_code, header_date: new_date, entry_deadline: (new_date - 15.days) },
          { code: fixture_code, timing_type_id: GogglesDb::TimingType.send(%w[manual semiauto automatic].sample).id },
          { edition_type_id: GogglesDb::EditionType.send(%w[ordinal roman none yearly seasonal].sample).id, edition: (rand * 20).to_i },
          { warm_up_pool: [false, true].sample, allows_under25: [false, true].sample, confirmed: [false, true].sample }
        ].sample
      end

      before do
        expect(expected_changes).to be_an(Hash)
        expect(fixture_row).to be_a(GogglesDb::Meeting).and be_valid
      end

      context 'with an account having CRUD grants,' do
        before { put(api_v3_meeting_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_meeting_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
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
          let(:fixture_row2) { FactoryBot.create(:meeting) }

          before { expect(fixture_row2).to be_a(GogglesDb::Meeting).and be_valid }

          context 'with an account having ADMIN grants,' do
            let(:admin_user) { FactoryBot.create(:user) }
            let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
            let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }

            before do
              expect(admin_user).to be_a(GogglesDb::User).and be_valid
              expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
              expect(admin_headers).to be_an(Hash).and have_key('Authorization')
              put(api_v3_meeting_path(id: fixture_row2.id), params: admin_changes, headers: admin_headers)
            end

            it_behaves_like('a successful request that has positive usage stats')

            it 'updates the row and returns true' do
              expect(response.body).to eq('true')
              updated_row = fixture_row2.reload
              expect(updated_row.send(admin_changes.keys.first) == admin_changes.values.first).to be true
            end
          end

          context 'with an account having just CRUD grants,' do
            before { put(api_v3_meeting_path(id: fixture_row2.id), params: admin_changes, headers: crud_headers) }

            it_behaves_like('an empty but successful JSON response')
          end
        end
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_meeting_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_meeting_path(id: fixture_row.id), params: { code: fixture_code }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_meeting_path(id: -1), params: { code: fixture_code }, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/meeting/clone/:id' do
    shared_examples_for('a successful JSON cloned Meeting response') do
      it_behaves_like('a successful request that has positive usage stats')
      it 'returns an OK message and the new row as a JSON object with some fields cleared out' do
        result = JSON.parse(response.body)
        expect(result).to have_key('msg').and have_key('new')
        expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
        resulting_hash = result['new']
        expect(resulting_hash['id'].to_i).to be_positive
        expect(resulting_hash['header_date']).to be_present
        expect(resulting_hash['header_year']).to be_present
        # Edition must be increased:
        expect(resulting_hash['edition'].to_i).to eq(fixture_row.edition + 1)
        # Misc columns that must be cleared out:
        expect(
          %w[entry_deadline manifest_body].all? { |key| resulting_hash[key].nil? }
        ).to be true
        expect(
          %w[manifest startlist autofilled confirmed tweeted
             posted cancelled pb_acquired read_only].all? { |key| resulting_hash[key] == false }
        ).to be true
      end
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_meeting_clone_path(id: fixture_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON cloned Meeting response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_meeting_clone_path(id: fixture_row.id), headers: crud_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_meeting_clone_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_meeting_clone_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON cloned Meeting response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_meeting_clone_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_meeting_clone_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { post(api_v3_meeting_clone_path(id: -1), headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with an error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('msg')
        expect(result['msg']).to eq('Invalid constructor parameters')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/meetings/' do
    context 'when using a valid authentication' do
      # actual Meeting count x recent Seasons: 141=6, 142=143, 151=6, 152=141, 161=6, 162=147, 171=5, 172=144, 181=4, 182=88, 191=3, 192=16
      let(:many_pages_season_id) { [142, 152, 162, 172, 182].sample }
      let(:fixture_description) { %w[Riccione CSI].sample }
      let(:fixture_description) { %w[Riccione CSI].sample }
      let(:single_page_season_id) { [141, 151, 161, 171, 181, 191, 192].sample }
      let(:default_per_page) { 25 }

      # Make sure the Domain contains the expected seeds:
      before do
        expect(GogglesDb::Meeting.select(:id).where(season_id: many_pages_season_id).count).to be > default_per_page
        expect(GogglesDb::Meeting.select(:id).where(season_id: single_page_season_id).count).to be <= default_per_page
      end

      context 'without any filters,' do
        before { get(api_v3_meetings_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'during Maintenance mode with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meetings_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'during Maintenance mode with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_meetings_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'and filtering by a specific season (yielding > 25 meetings),' do
        before { get(api_v3_meetings_path, params: { season_id: many_pages_season_id }, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'and filtering by a specific season (yielding <= 25 meetings),' do
        let(:expected_row_count) { GogglesDb::Meeting.select(:id).where(season_id: single_page_season_id).count }

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meetings_path, params: { season_id: single_page_season_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'and filtering by a specific date and season,' do
        let(:meetings_in_domain) { GogglesDb::Meeting.joins(:meeting_sessions).includes(:meeting_sessions).where(season_id: many_pages_season_id) }
        let(:sample_date) { meetings_in_domain.sample.header_date }
        let(:expected_row_count) do
          meetings_in_domain.where('(header_date = ?) OR (meeting_sessions.scheduled_date = ?)', sample_date, sample_date)
                            .distinct.count
        end

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meetings_path, params: { date: sample_date, season_id: many_pages_season_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'and filtering by a specific pool_type and season,' do
        let(:fixture_pool_type_id) { GogglesDb::PoolType.all_eventable.sample.id }
        let(:expected_row_count) do
          GogglesDb::Meeting.joins(meeting_sessions: :swimming_pool).includes(meeting_sessions: :swimming_pool)
                            .where(season_id: many_pages_season_id, 'swimming_pools.pool_type_id': fixture_pool_type_id)
                            .distinct.count
        end

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meetings_path, params: { pool_type_id: fixture_pool_type_id, season_id: many_pages_season_id }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'and filtering by name,' do
        let(:expected_row_count) do
          GogglesDb::Meeting.joins(:meeting_sessions).includes(:meeting_sessions)
                            .for_name(fixture_description)
                            .distinct.count
        end

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meetings_path, params: { name: fixture_description }, headers: fixture_headers)
        end

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when enabling custom Select2 output,' do
        let(:expected_row_count) do
          GogglesDb::Meeting.joins(:meeting_sessions).includes(:meeting_sessions)
                            .for_name(fixture_description)
                            .distinct.limit(100).count
        end

        before do
          expect(expected_row_count).to be_positive
          get(api_v3_meetings_path, params: { name: fixture_description, select2_format: true }, headers: fixture_headers)
        end

        it_behaves_like('successful response in Select2 bespoke format')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_meetings_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'and filtering by a non-existing value,' do
      before { get(api_v3_meetings_path, params: { date: '1986-01-01' }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end

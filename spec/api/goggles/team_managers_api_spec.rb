# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::TeamManagersAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)   { FactoryBot.create(:user) }
  let(:jwt_token)  { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'POST /api/v3/team/manager' do
    let(:new_manager) { FactoryBot.create(:user) }
    let(:new_affiliation) { FactoryBot.create(:team_affiliation) }
    let(:built_row) { FactoryBot.build(:managed_affiliation, manager: new_manager, team_affiliation: new_affiliation) }
    let(:admin_user) { FactoryBot.create(:user) }
    let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
    let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
    before(:each) do
      expect(new_manager).to be_a(GogglesDb::User).and be_valid
      expect(new_affiliation).to be_a(GogglesDb::TeamAffiliation).and be_valid
      expect(built_row).to be_a(GogglesDb::ManagedAffiliation).and be_valid
      expect(admin_user).to be_a(GogglesDb::User).and be_valid
      expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(admin_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) { post(api_v3_team_manager_path, params: built_row.attributes, headers: admin_headers) }
        it 'is successful' do
          expect(response).to be_successful
        end
        it 'updates the row and returns the result msg and the new row as JSON' do
          result = JSON.parse(response.body)
          expect(result).to have_key('msg').and have_key('new')
          expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
          attr_extractor = ->(hash) { hash.reject { |key, _value| %w[id lock_version created_at updated_at].include?(key.to_s) } }
          expect(attr_extractor.call(result['new'])).to eq(attr_extractor.call(built_row.attributes))
        end
      end

      context 'with an account having just CRUD grants,' do
        let(:crud_user) { FactoryBot.create(:user) }
        let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'TeamAffiliation') }
        let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
        before(:each) do
          expect(crud_user).to be_a(GogglesDb::User).and be_valid
          expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
          expect(crud_headers).to be_an(Hash).and have_key('Authorization')
          post(api_v3_team_manager_path, params: built_row.attributes, headers: crud_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before(:each) { post(api_v3_team_manager_path, params: built_row.attributes, headers: fixture_headers) }
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        post(api_v3_team_manager_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' })
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when using missing or invalid parameters,' do
      before(:each) do
        post(api_v3_team_manager_path, params: { user_id: built_row.user_id, team_affiliation_id: -1 }, headers: admin_headers)
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
end

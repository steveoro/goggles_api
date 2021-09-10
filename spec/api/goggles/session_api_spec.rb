# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SessionAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }

  # Enforce domain context creation
  before do
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(admin_user).to be_a(GogglesDb::User).and be_valid
    expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
  end

  describe 'POST /api/:version/session' do
    shared_examples_for 'a successful new API session creation request' do
      it 'is successful' do
        expect(response).to be_successful
      end

      it 'responds with a message and the new value for the JWT' do
        result = JSON.parse(response.body)
        expect(result.keys).to match_array(%w[msg jwt])
        expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
        expect(result['jwt']).to be_a(String).and be_present
      end
    end

    context 'when using valid parameters,' do
      before { post(api_v3_session_path, params: { e: api_user.email, p: api_user.password, t: Rails.application.credentials.api_static_key }) }

      it_behaves_like('a successful new API session creation request')
      it 'returns a new valid JWT for the API user' do
        result = JSON.parse(response.body)
        decoded_jwt = GogglesDb::JWTManager.decode(result['jwt'], Rails.application.credentials.api_static_key)
        expect(decoded_jwt).to be_present
        expect(decoded_jwt).to have_key('user_id')
        expect(decoded_jwt['user_id']).to eq(api_user.id)
      end
    end

    context 'when using an *admin* user during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        post(api_v3_session_path, params: { e: admin_user.email, p: admin_user.password, t: Rails.application.credentials.api_static_key })
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a successful new API session creation request')
      it 'returns a new valid JWT for the API user' do
        result = JSON.parse(response.body)
        decoded_jwt = GogglesDb::JWTManager.decode(result['jwt'], Rails.application.credentials.api_static_key)
        expect(decoded_jwt).to be_present
        expect(decoded_jwt).to have_key('user_id')
        expect(decoded_jwt['user_id']).to eq(admin_user.id)
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        post(api_v3_session_path, params: { e: api_user.email, p: api_user.password, t: Rails.application.credentials.api_static_key })
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using invalid user credentials,' do
      before { post(api_v3_session_path, params: { e: 'non.existing.user@example.com', p: 'password', t: Rails.application.credentials.api_static_key }) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.unauthorized'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to eq(I18n.t('api.message.invalid_credentials'))
      end
    end

    context 'when using an invalid static token,' do
      before { post(api_v3_session_path, params: { e: api_user.email, p: api_user.password, t: 'NOT-the-correct-token-for-sure' }) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.unauthorized'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to eq(I18n.t('api.message.invalid_token'))
      end
    end
  end
end

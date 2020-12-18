require "rails_helper"

RSpec.describe Organized::ImpoundClaimsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/impound_claims" }
  include_context :request_spec_logged_in_as_organization_member

  let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }
  let(:user_email) { "someemail@things.com" }
  let(:user_claiming) { FactoryBot.create(:user_confirmed, email: user_email) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record, user: user_claiming) }
  let(:enabled_feature_slugs) { %w[parking_notifications impound_bikes] }
  let(:impound_record) { FactoryBot.create(:impound_record, organization: current_organization, user: current_user, bike: bike, display_id: 1111) }
  let(:impound_claim) { FactoryBot.create(:impound_claim, impound_record: impound_record, stolen_record: bike.current_stolen_record, status: "submitting") }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:impound_claims).count).to eq 0
    end
    context "multiple impound_records" do
      let(:bike2) { FactoryBot.create(:bike, serial_number: "yaris") }
      let!(:impound_claim2) { FactoryBot.create(:impound_claim_with_stolen_record, organization: current_organization, user: current_user, bike: bike2, status: "submitting") }
      let!(:impound_claim_approved) { FactoryBot.create(:impound_claim, organization: current_organization, status: "approved") }
      let!(:impound_claim_resolved) { FactoryBot.create(:impound_claim_resolved, organization: current_organization) }
      let!(:impound_claim_unorganized) { FactoryBot.create(:impound_claim) }
      it "finds by impound scoping" do
        impound_claim.reload
        expect(impound_claim.bike_submitting&.id).to eq bike.id
        expect(impound_claim.bike_claimed&.id).to eq bike.id
        expect(impound_claim.active?).to be_truthy
        expect(impound_claim.organization_id).to eq current_organization.id
        impound_claim2.reload
        expect(impound_claim2.active?).to be_truthy
        expect(impound_claim2.organization_id).to eq current_organization.id
        impound_claim_approved.reload
        expect(impound_claim_approved.active?).to be_truthy
        expect(impound_claim_approved.organization_id).to eq current_organization.id
        # Test that impound_claim.active.bikes scopes correctly
        active_ids = [impound_claim.id, impound_claim2.id, impound_claim_approved.id]
        expect(current_organization.impound_claims.active.pluck(:id)).to match_array(active_ids)
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:search_status)).to eq "active"
        expect(assigns(:impound_claims).pluck(:id)).to match_array(active_ids)


        get "#{base_url}?search_status=all"
        expect(response.status).to eq(200)
        expect(assigns(:search_status)).to eq "all"
        expect(assigns(:impound_claims).pluck(:id)).to match_array(active_ids + [impound_claim_resolved.id])

        get "#{base_url}?search_impound_record_id=#{impound_record.id}"
        expect(response.status).to eq(200)
        expect(assigns(:impound_claims).pluck(:id)).to match_array([impound_claim.id])
      end
    end
  end

  describe "show" do
    it "renders" do
      impound_claim.reload
      get "#{base_url}/#{impound_claim.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:impound_claim)).to eq impound_claim
    end
  end

  describe "update" do
    it "updates"
  end
end

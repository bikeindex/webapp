# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminHelper, type: :helper do
  # This is sort of gross, because of all the stubbing, but it's still useful, so...
  describe "admin_nav_display_view_all" do
    before do
      allow(helper).to receive(:request) { double("request", url: bikes_path) }
      allow(helper).to receive(:dev_nav_select_links) { [] } # Can't get current_user to stub :(
      controller.params = ActionController::Parameters.new(passed_params)
      admin_nav_active = helper.admin_nav_select_links.find { |v| v[:title] == "Bikes" }
      allow(helper).to receive(:admin_nav_select_link_active) { admin_nav_active }
      allow(view).to receive(:current_page?) { true }
    end

    context "period all" do
      let(:passed_params) { {period: "all", timezone: "Party"} }
      it "is false" do
        expect(helper.admin_nav_select_link_active[:match_controller]).to be_truthy
        expect(helper.admin_nav_display_view_all).to be_falsey
      end
      context "with sort" do
        let(:passed_params) { {direction: "desc", render_chart: "true", sort: "manufacturer_id"} }
        it "is false" do
          expect(helper.admin_nav_display_view_all).to be_falsey
        end
      end
      context "with period != all" do
        let(:passed_params) { {period: "week", timezone: "Party"} }
        it "is true" do
          expect(helper.admin_nav_display_view_all).to be_truthy
        end
      end
      context "not actual current_page" do
        it "is true" do
          allow(helper).to receive(:current_page_active?) { false }
          expect(helper.admin_nav_display_view_all).to be_truthy
        end
      end
    end
  end

  describe "mail_snippet_edit_path" do
    it "returns organization edit path for organization message" do
      mail_snippet = MailSnippet.new(kind: "parked_incorrectly_notification", organization_id: 12, id: 1)
      expect(edit_mail_snippet_path_for(mail_snippet)).to eq edit_organization_email_path("parked_incorrectly_notification", organization_id: 12)
    end
    it "returns admin path for custom" do
      mail_snippet = MailSnippet.new(kind: "custom", organization_id: 12, id: 2)
      expect(edit_mail_snippet_path_for(mail_snippet)).to eq edit_admin_mail_snippet_path(2)
    end
  end

  describe "credibility_scorer_color" do
    it "returns yellow for 50" do
      expect(credibility_scorer_color(50)).to eq "#ffc107"
    end
    it "returns red for 25" do
      expect(credibility_scorer_color(25)).to eq "#dc3545"
    end
    it "returns green for 80" do
      expect(credibility_scorer_color(80)).to eq "#28a745"
    end
  end

  describe "user_icon" do
    it "returns empty" do
      expect(user_icon(User.new)).to be_blank
    end
    context "donor" do
      let(:payment) { FactoryBot.create(:payment, kind: "donation") }
      let(:user) { payment.user }
      let(:target) { "<span><span class=\"donor-icon ml-1\">D</span></span>" }
      let(:target_full_text) { "<span><span class=\"donor-icon ml-1\">D</span><span class=\"less-strong\">onor</span></span>" }
      it "returns donor" do
        expect(user.donor?).to be_truthy
        expect(user_icon(user)).to eq target
        expect(user_icon(user, full_text: true)).to eq target_full_text
      end
      context "theft alert" do
        let!(:theft_alert) { FactoryBot.create(:theft_alert_paid, user: user) }
        let(:target) { "<span><span class=\"donor-icon ml-1\">D</span><span class=\"theft-alert-icon ml-1\">P</span></span>" }
        let(:target_full_text) do
          "<span><span class=\"donor-icon ml-1\">D</span><span class=\"less-strong\">onor</span>" +
          "<span class=\"theft-alert-icon ml-1\">P</span><span class=\"less-strong\">romoted alert</span>" +
          "</span>"
        end
        it "returns donor and theft alert" do
          expect(user.donor?).to be_truthy
          expect(user.theft_alert_purchaser?).to be_truthy
          expect(user_icon(user)).to eq target
          expect(user_icon(user, full_text: true)).to eq target_full_text
        end
      end
    end
    context "organization" do
      let(:organization) { FactoryBot.create(:organization, :organization_features) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:target) { "<span><span class=\"paid-org-icon ml-1\">O</span></span>" }
      let(:target_full_text) { "<span><span class=\"paid-org-icon ml-1\">O</span><span class=\"less-strong\">rganization member</span></span>" }
      it "returns paid_org" do
        expect(user.paid_org?).to be_truthy
        expect(user_icon(user)).to eq target
        expect(user_icon(user, full_text: true)).to eq target_full_text
      end
    end
  end
end

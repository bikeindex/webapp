require "rails_helper"

RSpec.describe MailchimpIntegration do
  let(:instance) { described_class.new }

  describe "get_lists" do
    let(:target) do
      [{name: "Individuals", id: "180a1141a4"},
        {name: "Organizations", id: "b675299293"},
        {name: "From Bike Index", id: "9246283c07"}]
    end
    it "gets the lists" do
      VCR.use_cassette("mailchimp_integration-get_lists", match_requests_on: [:path]) do
        expect(instance.get_lists).to match_array(target.as_json)
      end
    end
  end

  describe "member_update_hash" do
    let(:mailchimp_datum) { MailchimpDatum.create(email: "example@bikeindex.org") }
    let(:target) do
      {email: "example@bikeindex.org",
       full_name: nil,
       interests: [],
       merge_fields: target_merge_fields,
       status: "unsubscribed"}
    end
    let(:target_merge_fields) do
      {
        organization_kind: "bike_shop",
        organization_name: nil,
        organization_url: nil,
        organization_country: nil,
        organization_city: nil,
        organization_state: nil,
        organization_signed_up_at: nil,
        bikes: 0,
        name: mailchimp_datum.full_name,
        phone_number: nil,
        user_signed_up_at: mailchimp_datum.user&.created_at,
        added_to_mailchimp_at: nil
      }
    end
    it "is expected" do
      expect(mailchimp_datum.merge_fields.as_json).to eq target_merge_fields.as_json
      expect(instance.member_update_hash(mailchimp_datum, "organization").as_json).to eq target.as_json
    end
  end

  describe "get_member" do
    context "no existing member" do
      let(:mailchimp_datum) { MailchimpDatum.create(email: "example@bikeindex.org") }
      it "gets mailchimp response" do
        expect(mailchimp_datum.id).to be_blank
        expect(mailchimp_datum.subscriber_hash).to eq "ae3dd3401b5ed77b0a23d85874d6113b"

        VCR.use_cassette("mailchimp_integration-get_member-example", match_requests_on: [:path]) do
          result = instance.get_member(mailchimp_datum, "individual")
          expect(result).to eq nil
        end
      end
    end
  end

  describe "get_interest_categories" do
    let(:target) { [{list_id: "180a1141a4", id: "bec514f886", title: "Bike Index user types", display_order: 0, type: "hidden"}] }
    it "gets interest categories" do
      VCR.use_cassette("mailchimp_integration-get_interest_categories", match_requests_on: [:path]) do
        categories = instance.get_interest_categories("individual")
        pp categories
        expect(categories).to eq target.as_json
        # expect(instance.get_interest_categories("individual")).to eq target.as_json
      end
    end
  end
end

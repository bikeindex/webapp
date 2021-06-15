require "rails_helper"

RSpec.describe UpdateMailchimpDatumWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    context "organization" do
      let(:target_body) do
        {email_address: "seth@bikeindex.org",
         full_name: "Seth Herr",
         interests: {"c5bbab099c" => true},
         merge_fields: target_merge_fields,
         status_if_new: "subscribed"}
      end
      let(:user) { FactoryBot.create(:user, email: "seth@bikeindex.org", name: "Seth Herr") }
      let(:organization_created_at) { Time.at(1552072143) }
      let(:target_merge_fields) { {"NAME" => "Seth Herr", "O_NAME" => "Hogwarts", "O_AT" => organization_created_at} }
      let(:organization) { FactoryBot.create(:organization, kind: "school", name: "Hogwarts", created_at: organization_created_at) }
      let(:membership) { FactoryBot.create(:membership_claimed, organization: organization, user: user, role: "admin") }
      let(:mailchimp_datum) { MailchimpDatum.find_or_create_for(user) }

      context "organization creator, create user" do
        let!(:invoice) { FactoryBot.create(:invoice_paid, organization: organization) }
        before do
          MailchimpValue.create(kind: "interest", slug: "school", mailchimp_id: "c5bbab099c", list: "organization")
          MailchimpValue.create(kind: "merge_field", slug: "name", mailchimp_id: "NAME", list: "organization")
          MailchimpValue.create(kind: "merge_field", slug: "organization-name", mailchimp_id: "O_NAME", list: "organization")
          MailchimpValue.create(kind: "merge_field", slug: "organization-sign-up", mailchimp_id: "O_AT", list: "organization")
          MailchimpValue.create(kind: "tag", slug: "in-bike-index", mailchimp_id: "87306", list: "organization")
          MailchimpValue.create(kind: "tag", slug: "paid", mailchimp_id: "1881982", list: "organization")
          MailchimpValue.create(kind: "tag", slug: "not-organization-creator", mailchimp_id: "1882022", list: "organization")
        end
        let(:target_tags) { %w[paid in-bike-index] }
        it "updates mailchimp_datums" do
          expect(membership.organization_creator?).to be_truthy
          organization.update(updated_at: Time.current)
          expect(mailchimp_datum).to be_valid
          mailchimp_datum.reload
          expect(mailchimp_datum.mailchimp_organization&.paid?).to be_truthy
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.lists).to eq(["organization"])
          expect(mailchimp_datum.on_mailchimp?).to be_falsey
          expect(mailchimp_datum.mailchimp_interests("organization")).to eq(target_body[:interests])
          expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq target_merge_fields
          expect(MailchimpIntegration.new.member_update_hash(mailchimp_datum, "organization")).to eq target_body
          expect(mailchimp_datum.tags).to match_array target_tags

          VCR.use_cassette("update_mailchimp_datum_worker-organization-create", match_requests_on: [:path]) do
            instance.perform(mailchimp_datum.id)
          end
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.on_mailchimp?).to be_truthy
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.interests).to eq(["school"])
          expect(mailchimp_datum.mailchimp_interests("organization")).to eq(target_body[:interests])
          expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq target_merge_fields
          expect(MailchimpIntegration.new.member_update_hash(mailchimp_datum, "organization")).to eq target_body
          expect(mailchimp_datum.tags).to match_array target_tags
        end
      end
      context "not creator, update user" do
        before do
          MailchimpValue.create(kind: "merge_field", slug: "organization-city", mailchimp_id: "CITY", list: "organization")
          MailchimpValue.create(kind: "merge_field", slug: "organization-state", mailchimp_id: "STATE", list: "organization")
          MailchimpValue.create(kind: "merge_field", slug: "organization-country", mailchimp_id: "COUNTRY", list: "organization")
          MailchimpValue.create(kind: "tag", slug: "not-organization-creator", mailchimp_id: "1882022", list: "organization")
        end
        let!(:location) { FactoryBot.create(:location_los_angeles, organization: organization) }
        let(:merge_address_fields) { {"CITY" => "Los Angeles", "STATE" => "CA", "COUNTRY" => "US"} }
        let(:target_tags) { %w[paid in-bike-index not-organization-creator] }
        it "updates mailchimp_datums" do
          FactoryBot.create(:membership_claimed, organization: organization)
          organization.update(updated_at: Time.current)
          expect(organization.default_location&.id).to eq location.id
          expect(membership.reload.organization_creator?).to be_falsey
          expect(organization.reload.paid?).to be_falsey
          expect(mailchimp_datum).to be_valid
          mailchimp_datum.reload
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.lists).to eq(["organization"])
          expect(mailchimp_datum.on_mailchimp?).to be_falsey
          expect(mailchimp_datum.mailchimp_interests("organization")).to eq({})
          expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq merge_address_fields
          expect(mailchimp_datum.tags).to eq(%w[in-bike-index not-organization-creator])

          VCR.use_cassette("update_mailchimp_datum_worker-organization-update", match_requests_on: [:path]) do
            instance.perform(mailchimp_datum.id)
          end
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.on_mailchimp?).to be_truthy
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.interests).to eq(["c5bbab099c", "school"])
          # expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq target_merge_fields.merge(merge_address_fields)
          expect(MailchimpIntegration.new.member_update_hash(mailchimp_datum, "organization")).to eq target_body
          expect(mailchimp_datum.tags).to match_array target_tags
        end
      end
    end
  end
end

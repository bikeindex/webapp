require "rails_helper"

RSpec.describe BikeSticker, type: :model do
  describe "normalize_code" do
    let(:url) { "https://bikeindex.org/bikes/scanned/000012?organization_id=palo-party" }
    let(:url2) { "bikeindex.org/bikes/000012/scanned?organization_id=bikeindex" }
    let(:url3) { "www.bikeindex.org/bikes/12/scanned?organization_id=bikeindex" }
    let(:url4) { "https://bikeindex.org/bikes/scanned/000012/" }
    let(:code) { "bike_code999" }
    it "strips the right stuff" do
      expect(BikeSticker.normalize_code(code)).to eq "BIKE_CODE999"
      expect(BikeSticker.normalize_code(url)).to eq "12"
      expect(BikeSticker.normalize_code(url2)).to eq "12"
      expect(BikeSticker.normalize_code(url3)).to eq "12"
      expect(BikeSticker.normalize_code(url4)).to eq "12"
    end
  end

  describe "basic stuff" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:organization) { FactoryBot.create(:organization, name: "Bike all night long", short_name: "bikenight") }
    let!(:spokecard) { FactoryBot.create(:bike_sticker, kind: "spokecard", code: 12, bike: bike) }
    let!(:sticker) { FactoryBot.create(:bike_sticker, code: 12, organization_id: organization.id) }
    let!(:sticker_dupe) { FactoryBot.build(:bike_sticker, code: "00012", organization_id: organization.id) }
    let!(:spokecard_text) { FactoryBot.create(:bike_sticker, kind: "spokecard", code: "a31b", bike: bike) }

    it "calls the things we expect and finds the things we expect" do
      expect(BikeSticker.claimed.count).to eq 2
      expect(BikeSticker.unclaimed.count).to eq 1
      expect(BikeSticker.spokecard.count).to eq 2
      expect(BikeSticker.sticker.count).to eq 1
      expect(BikeSticker.lookup("92233720368547758999")).to be_blank # Outside of range
      expect(BikeSticker.lookup("000012", organization_id: organization.id)).to eq sticker
      expect(BikeSticker.lookup("000012", organization_id: organization.to_param)).to eq sticker
      expect(BikeSticker.lookup("https://bikeindex.org/bikes/scanned/000012?organization_id=#{organization.short_name}", organization_id: organization.short_name)).to eq sticker
      expect(BikeSticker.lookup("000012", organization_id: organization.name)).to eq sticker
      expect(BikeSticker.lookup("000012", organization_id: "whateves")).to eq spokecard
      expect(BikeSticker.lookup("000012")).to eq spokecard
      expect(BikeSticker.admin_text_search("1").pluck(:id)).to match_array([spokecard_text.id, spokecard.id, sticker.id])
      expect(BikeSticker.admin_text_search(" ").pluck(:id)).to match_array([spokecard.id, sticker.id, spokecard_text.id])
      expect(BikeSticker.admin_text_search("0012").pluck(:id)).to match_array([spokecard.id, sticker.id])
      expect(BikeSticker.admin_text_search("a").pluck(:id)).to match_array([spokecard_text.id])
      expect(spokecard.claimed?).to be_truthy
      expect(sticker_dupe.save).to be_falsey
    end
  end

  describe "claimed?" do
    it "is not claimed if bike doesn't exist" do
      expect(BikeSticker.new(bike_id: 12123123).claimed?).to be_falsey
    end
  end

  describe "code_integer code_prefix and pretty_lookup" do
    let(:bike_sticker) { BikeSticker.new(code: "b02012012") }
    before { bike_sticker.set_calculated_attributes }
    it "separates" do
      expect(bike_sticker.code_integer).to eq 2012012
      expect(bike_sticker.code_prefix).to eq "B"
      expect(bike_sticker.pretty_code).to eq("B 201 201 2")
    end
    context "0" do
      let(:bike_sticker) { BikeSticker.new(code: "a00") }
      it "separates" do
        expect(bike_sticker.code_integer).to eq 0
        expect(bike_sticker.code_prefix).to eq "A"
        expect(bike_sticker.pretty_code).to eq("A 0")
      end
    end
    context "bike_sticker_batch has a set length" do
      let(:bike_sticker) { FactoryBot.create(:bike_sticker, code: "A0001", bike_sticker_batch_id: bike_sticker_batch.id) }
      let(:bike_sticker2) { FactoryBot.create(:bike_sticker, code: "A102", bike_sticker_batch_id: bike_sticker_batch.id) }
      let(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch, code_number_length: 5) }
      it "renders the pretty print from the batch length" do
        expect(bike_sticker.pretty_code).to eq "A 000 01"
        expect(bike_sticker2.pretty_code).to eq "A 001 02"
        expect(BikeSticker.lookup("A 01")).to eq(bike_sticker)
        expect(BikeSticker.lookup("A 001 02")).to eq(bike_sticker2)
      end
    end
  end

  describe "lookup_with_fallback" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:organization_duplicate) { FactoryBot.create(:organization, short_name: "DuplicateOrg") }
    let(:organization_no_match) { FactoryBot.create(:organization) }
    let!(:bike_sticker_initial) { FactoryBot.create(:bike_sticker, code: "a0010", organization: organization) }
    let(:bike_sticker_duplicate) { FactoryBot.create(:bike_sticker, code: "a0010", organization: organization_duplicate) }
    let!(:user) { FactoryBot.create(:organization_member, organization: organization_duplicate) }
    it "looks up, falling back to the orgs for the user, falling back to any org" do
      expect(bike_sticker_duplicate).to be_present # Ensure it's created after initial
      # It finds the first record in the database
      expect(BikeSticker.lookup_with_fallback("a0010")).to eq bike_sticker_initial
      expect(BikeSticker.lookup_with_fallback("0010")).to eq bike_sticker_initial
      # If there is an organization passed, it finds matching that organization
      expect(BikeSticker.lookup_with_fallback("0010", organization_id: organization_duplicate.name)).to eq bike_sticker_duplicate
      expect(BikeSticker.lookup_with_fallback("A10", organization_id: "duplicateorg")).to eq bike_sticker_duplicate
      # It finds the bike_sticker that exists, even if it doesn't match the organization passed
      expect(BikeSticker.lookup_with_fallback("a0010", organization_id: organization_no_match.short_name)).to eq bike_sticker_initial
      # It finds the bike_sticker from the user's organization
      expect(BikeSticker.lookup_with_fallback("a0010", user: user)).to eq bike_sticker_duplicate
      # It finds bike_sticker that matches the passed organization - overriding the user organization
      expect(BikeSticker.lookup_with_fallback("a0010", organization_id: organization, user: user)).to eq bike_sticker_initial
      # It falls back to the user's organization bike codes if passed an organization that doesn't match any codes, or an org that doesn't exist
      expect(BikeSticker.lookup_with_fallback("A 00 10", organization_id: organization_no_match.id, user: user)).to eq bike_sticker_duplicate
      expect(BikeSticker.lookup_with_fallback("A 000 10", organization_id: "dfddfdfs", user: user)).to eq bike_sticker_duplicate
    end
  end

  describe "duplication and integers" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:sticker) { FactoryBot.create(:bike_sticker, kind: "sticker", code: 12, organization_id: organization.id) }
    let!(:sticker2) { FactoryBot.create(:bike_sticker, kind: "sticker", code: " 12", organization: FactoryBot.create(:organization)) }
    let!(:spokecard) { FactoryBot.create(:bike_sticker, kind: "spokecard", code: "00000012") }
    let!(:spokecard2) { FactoryBot.create(:bike_sticker, kind: "sticker", code: "a00000012") }
    let(:sticker_dupe_number) { FactoryBot.build(:bike_sticker, kind: "sticker", code: "00012", organization_id: organization.id) }
    # Note: unique across kinds, so just check that here
    let(:spokecard_dupe_letter) { FactoryBot.build(:bike_sticker, kind: "sticker", code: " A00000012") }
    let(:spokecard_empty) { FactoryBot.build(:bike_sticker, kind: "sticker", code: " ") }

    it "doesn't permit duplicates" do
      expect(sticker.code).to eq "12"
      expect(sticker2.code).to eq "12"
      expect(spokecard2.code).to eq "A00000012"
      [sticker, sticker2, spokecard, spokecard2].each { |bike_sticker| expect(bike_sticker).to be_valid }
      expect(sticker_dupe_number.save).to be_falsey
      expect(sticker_dupe_number.errors.messages.to_s).to match(/already been taken/i)
      expect(spokecard_dupe_letter.save).to be_falsey
      expect(sticker_dupe_number.errors.messages.to_s).to match(/already been taken/i)
      expect(spokecard_empty.save).to be_falsey
      expect(spokecard_empty.errors.messages.to_s).to match(/blank/i)
    end
  end

  describe "next_unassigned" do
    let(:bike_sticker) { FactoryBot.create(:bike_sticker, organization_id: 12, code: "zzzz") }
    let(:bike_sticker1) { FactoryBot.create(:bike_sticker, organization_id: 12, code: "a1111") }
    let(:bike_sticker2) { FactoryBot.create(:bike_sticker, organization_id: 11, code: "a1112") }
    let(:bike_sticker3) { FactoryBot.create(:bike_sticker, organization_id: 12, code: "a1113", bike_id: 12) }
    let(:bike_sticker4) { FactoryBot.create(:bike_sticker, organization_id: 12, code: "a111") }
    it "finds next unassigned, returns nil if not found" do
      expect([bike_sticker, bike_sticker1, bike_sticker2, bike_sticker3, bike_sticker4].size).to eq 5
      expect(bike_sticker1.next_unclaimed_code).to eq bike_sticker4
      expect(bike_sticker2.next_unclaimed_code).to be_nil
    end
    context "an unassigned lower code" do
      let!(:earlier_unclaimed) { FactoryBot.create(:bike_sticker, organization_id: 12, code: "a1110") }
      it "grabs the next one anyway" do
        expect([earlier_unclaimed, bike_sticker, bike_sticker1, bike_sticker2, bike_sticker3, bike_sticker4].size).to eq 6
        expect(earlier_unclaimed.id).to be < bike_sticker4.id
        # expect(BikeSticker.where(organization_id: 12).next_unclaimed_code).to eq bike_sticker4
        expect(BikeSticker.where(organization_id: 11).next_unclaimed_code).to eq bike_sticker2
      end
    end
  end

  describe "organization_authorized?" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization) }
    it "returns false for no organization passed, true for the same organization" do
      expect(bike_sticker.organization_authorized?).to be_falsey
      expect(bike_sticker.organization_authorized?(organization)).to be_truthy
    end
    context "organization varieties" do
      let(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization) }
      let(:organization_regional) { FactoryBot.create(:organization, :in_edmonton) }
      let(:organization) { FactoryBot.create(:organization_with_regional_bike_counts, :in_edmonton, regional_ids: [organization_regional.id]) }
      let(:organization_child) { FactoryBot.create(:organization_child, parent_organization: organization) }
      let(:organization_other) { FactoryBot.create(:organization) }
      let(:organization_ambassador) { FactoryBot.create(:organization_ambassador) }
      let!(:bike_sticker_child) { FactoryBot.create(:bike_sticker, organization: organization_child) }
      let!(:bike_sticker_regional) { FactoryBot.create(:bike_sticker, organization: organization_regional) }
      let(:bike_sticker_other) { FactoryBot.create(:bike_sticker, organization: organization_other) }
      let(:bike_sticker_no_organization) { FactoryBot.create(:bike_sticker, organization: nil) }
      it "returns true for regional organization" do
        expect(organization.paid?).to be_truthy
        expect(organization_child.paid?).to be_truthy
        expect(organization_regional.paid?).to be_falsey
        expect(organization_other.paid?).to be_falsey
        # bike sticker for Main organization
        expect(bike_sticker.organization_authorized?(organization)).to be_truthy
        expect(bike_sticker.organization_authorized?(organization_child)).to be_truthy
        expect(bike_sticker.organization_authorized?(organization_regional)).to be_truthy
        expect(bike_sticker.organization_authorized?(organization_other)).to be_falsey
        expect(bike_sticker.organization_authorized?(organization_ambassador)).to be_truthy
        # child sticker
        expect(bike_sticker_child.organization_authorized?(organization)).to be_truthy
        expect(bike_sticker_child.organization_authorized?(organization_child)).to be_truthy
        expect(bike_sticker_child.organization_authorized?(organization_regional)).to be_falsey
        expect(bike_sticker_child.organization_authorized?(organization_other)).to be_falsey
        expect(bike_sticker_child.organization_authorized?(organization_ambassador)).to be_truthy
        # regional org sticker
        expect(bike_sticker_regional.organization_authorized?(organization)).to be_truthy
        expect(bike_sticker_regional.organization_authorized?(organization_child)).to be_truthy
        expect(bike_sticker_regional.organization_authorized?(organization_regional)).to be_truthy
        expect(bike_sticker_regional.organization_authorized?(organization_other)).to be_falsey
        expect(bike_sticker_regional.organization_authorized?(organization_ambassador)).to be_truthy
        # other organization sticker
        expect(bike_sticker_other.organization_authorized?(organization)).to be_truthy
        expect(bike_sticker_other.organization_authorized?(organization_child)).to be_truthy
        expect(bike_sticker_other.organization_authorized?(organization_regional)).to be_falsey
        expect(bike_sticker_other.organization_authorized?(organization_other)).to be_truthy
        expect(bike_sticker_other.organization_authorized?(organization_ambassador)).to be_truthy
        # no organization sticker
        expect(bike_sticker_no_organization.organization_authorized?(organization)).to be_truthy
        expect(bike_sticker_no_organization.organization_authorized?(organization_child)).to be_truthy
        expect(bike_sticker_no_organization.organization_authorized?(organization_regional)).to be_falsey
        expect(bike_sticker_no_organization.organization_authorized?(organization_other)).to be_falsey
        expect(bike_sticker_no_organization.organization_authorized?(organization_ambassador)).to be_truthy
      end
    end
  end

  describe "claimable_by?" do
    before { stub_const("BikeSticker::MAX_UNORGANIZED", 2) }
    context "user" do
      let(:bike_sticker1) { FactoryBot.create(:bike_sticker) }
      let(:bike_sticker2) { FactoryBot.create(:bike_sticker) }
      let(:bike_sticker3) { FactoryBot.create(:bike_sticker) }
      let(:bike1) { bike_sticker1.bike }
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      it "is truthy if fewer than MAX_UNORGANIZED bike_sticker_updates" do
        expect(bike_sticker1.claimable_by?(user)).to be_truthy
        expect(bike_sticker1.claimable_by?(user, organization)).to be_truthy
        expect(bike_sticker2.claimable_by?(user)).to be_truthy
        expect(bike_sticker2.claimable_by?(user, organization)).to be_truthy
        expect(bike_sticker3.claimable_by?(user)).to be_truthy
        expect(bike_sticker3.claimable_by?(user, organization)).to be_truthy
        expect(bike_sticker1.organization_authorized?(organization)).to be_falsey
        expect(bike_sticker2.organization_authorized?(organization)).to be_falsey
        expect(bike_sticker3.organization_authorized?(organization)).to be_falsey
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker1, bike: bike1)
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker2, bike: bike1, organization: organization)
        bike_sticker1.reload
        bike_sticker2.reload
        bike_sticker3.reload
        expect(bike_sticker1.claimable_by?(user)).to be_truthy
        expect(bike_sticker1.claimable_by?(user, organization)).to be_truthy # Not authorized by organization tho
        expect(bike_sticker2.claimable_by?(user)).to be_truthy
        expect(bike_sticker2.claimable_by?(user, organization)).to be_truthy # Not authorized by organization tho
        expect(bike_sticker3.claimable_by?(user)).to be_falsey
        # If user is superuser, it's claimable
        user.update(superuser: true)
        expect(bike_sticker3.claimable_by?(user)).to be_truthy
        expect(bike_sticker3.claimable_by?(user, organization)).to be_truthy
      end
    end
    context "bike sticker is for a regional org" do
      let(:bike_sticker1) { FactoryBot.create(:bike_sticker, organization: organization) }
      let(:bike_sticker2) { FactoryBot.create(:bike_sticker, organization: organization) }
      let(:bike_sticker3) { FactoryBot.create(:bike_sticker, organization: organization) }
      let(:organization_regional) { FactoryBot.create(:organization, :in_edmonton) }
      let(:organization) { FactoryBot.create(:organization_with_regional_bike_counts, :in_edmonton, regional_ids: [organization_regional.id]) }
      let(:organization_other) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization_regional) }
      let(:bike1) { bike_sticker1.bike }
      before { FactoryBot.create(:membership_claimed, user: user, organization: organization_other) }
      it "is truthy for regional org" do
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker1, bike: bike1, kind: "failed_claim") # Ignored, because failed
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker2, bike: bike1, kind: "failed_claim") # Ignored, because failed
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker2, bike: bike1, kind: "failed_claim") # Ignored, because failed
        expect(user.authorized?(organization_regional)).to be_truthy
        expect(user.authorized?(organization_other)).to be_truthy
        expect(user.authorized?(organization)).to be_falsey
        expect(bike_sticker1.claimable_by?(user)).to be_truthy
        expect(bike_sticker1.claimable_by?(user, organization_other)).to be_truthy
        expect(bike_sticker2.claimable_by?(user, organization_regional)).to be_truthy
        expect(bike_sticker2.claimable_by?(user, organization)).to be_falsey # user not authorized on organization
        expect(bike_sticker3.claimable_by?(user, organization_other)).to be_truthy
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker1, bike: bike1, organization: organization_regional)
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker2, bike: bike1, organization: organization_regional)
        expect(user.bike_sticker_updates.unauthorized_organization.count).to eq 0
        expect(bike_sticker1.organization_authorized?(organization_other)).to be_falsey
        expect(bike_sticker1.claimable_by?(user, organization_other)).to be_truthy
        expect(bike_sticker2.organization_authorized?(organization_other)).to be_falsey
        expect(bike_sticker2.claimable_by?(user, organization_other)).to be_truthy
        expect(bike_sticker3.claimable_by?(user, organization_other)).to be_truthy
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker1, bike: bike1)
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker2, bike: bike1, organization: organization_other)
        user.reload
        pp user.bike_sticker_updates.distinct.pluck(:bike_sticker_id)
        expect(user.unauthorized_organization_update_bike_sticker_ids).to match_array([bike_sticker1.id, bike_sticker2.id])
        expect(bike_sticker1.claimable_by?(user, organization_other)).to be_truthy # user already claimed bike_sticker already edited
        expect(bike_sticker2.claimable_by?(user, organization_other)).to be_truthy # user already claimed bike_sticker already edited
        expect(bike_sticker2.claimable_by?(user, organization_other)).to be_falsey # user isn't authorized on the organization
        expect(bike_sticker3.claimable_by?(user)).to be_truthy # authorized by the regional organization
        expect(bike_sticker3.claimable_by?(user, organization_regional)).to be_truthy
        expect(bike_sticker3.claimable_by?(user, organization_other)).to be_falsey
        expect(bike_sticker3.claimable_by?(user, organization)).to be_falsey # Even because user isn't authorized on the organization
      end
    end
  end

  describe "claim" do
    context "not claimable_by?" do
      before { stub_const("BikeSticker::MAX_UNORGANIZED", 1) }
      let(:bike_sticker1) { FactoryBot.create(:bike_sticker) }
      let(:bike_sticker2) { FactoryBot.create(:bike_sticker, organization: organization) }
      let(:organization) { FactoryBot.create(:organization) }
      let(:organization_paid) { FactoryBot.create(:organization_with_paid_features) }
      let(:bike1) { bike_sticker1.bike }
      let(:user) { FactoryBot.create(:user) }
      it "claims anyway" do
        expect(user.authorized?(organization)).to be_falsey
        FactoryBot.create(:bike_sticker_update, user: user, bike_sticker: bike_sticker1)
        # Not passing in organization
        expect(bike_sticker2.claimable_by?(user)).to be_falsey
        expect(bike_sticker2.claimable_by?(user, organization)).to be_falsey
        expect { bike_sticker2.claim(user: user, bike: bike1) }.to change(BikeStickerUpdate, :count).by 1
        bike_sticker2.reload
        expect(bike_sticker2.claimed?).to be_truthy
        expect(bike_sticker2.user).to eq user
        expect(bike_sticker2.secondary_organization).to be_blank
        bike_sticker_update1 = bike_sticker2.bike_sticker_updates.last
        expect(bike_sticker_update1.user).to eq user
        expect(bike_sticker_update1.organization).to be_blank
        expect(bike_sticker_update1.bike).to eq bike1
        expect(bike_sticker_update1.organization_kind).to eq "no_organization"
        expect(bike_sticker_update1.unauthorized_organization?).to be_truthy
        expect(bike_sticker_update1.kind).to eq "initial_claim"
        # Manually passing unauthorized organization in
        expect(bike_sticker1.claimed?).to be_falsey
        expect(bike_sticker1.claimable_by?(user)).to be_truthy
        expect(bike_sticker1.claimable_by?(user, organization)).to be_falsey # Because user isn't authorized on that org
        expect(bike_sticker1.organization_authorized?(organization)).to be_falsey
        expect { bike_sticker1.claim(user: user, bike: bike1, organization: organization) }.to change(BikeStickerUpdate, :count).by 1
        bike_sticker1.reload
        expect(bike_sticker1.claimed?).to be_truthy
        expect(bike_sticker1.user).to eq user
        expect(bike_sticker1.organization).to be_blank
        expect(bike_sticker1.secondary_organization).to be_blank
        bike_sticker_update2 = bike_sticker1.bike_sticker_updates.last
        expect(bike_sticker_update2.user).to eq user
        expect(bike_sticker_update2.organization).to eq organization
        expect(bike_sticker_update2.bike).to eq bike1
        expect(bike_sticker_update2.organization_kind).to eq "other_organization"
        expect(bike_sticker_update2.unauthorized_organization?).to be_truthy
        expect(bike_sticker_update2.kind).to eq "initial_claim"
        # blank bike, manually passing in organization that is authorized
        expect(bike_sticker2.claimed?).to be_truthy
        expect(bike_sticker2.claimable_by?(user)).to be_falsey
        expect(bike_sticker2.organization_authorized?(organization_paid)).to be_truthy
        expect { bike_sticker2.claim(user: user, organization: organization_paid) }.to change(BikeStickerUpdate, :count).by 1
        bike_sticker2.reload
        expect(bike_sticker2.claimed?).to be_falsey
        expect(bike_sticker2.user).to eq user
        expect(bike_sticker2.secondary_organization).to be_blank # Because the sticker is now unclaimed
        bike_sticker_update3 = bike_sticker2.bike_sticker_updates.last
        expect(bike_sticker_update3.user).to eq user
        expect(bike_sticker_update3.organization).to eq organization_paid
        expect(bike_sticker_update3.bike).to be_blank
        expect(bike_sticker_update3.organization_kind).to eq "primary_organization"
        expect(bike_sticker_update3.unauthorized_organization?).to be_falsey
        expect(bike_sticker_update3.kind).to eq "un_claim"
        # claiming with organization_paid
        expect { bike_sticker2.claim(user: user, bike: bike1, organization: organization_paid) }.to change(BikeStickerUpdate, :count).by 1
        bike_sticker2.reload
        expect(bike_sticker2.claimed?).to be_truthy
        expect(bike_sticker2.user).to eq user
        expect(bike_sticker2.secondary_organization).to eq organization_paid
        bike_sticker_update4 = bike_sticker2.bike_sticker_updates.last
        expect(bike_sticker_update4.user).to eq user
        expect(bike_sticker_update4.organization).to eq organization_paid
        expect(bike_sticker_update4.bike).to be_blank
        expect(bike_sticker_update4.organization_kind).to eq "other_paid_organization"
        expect(bike_sticker_update4.unauthorized_organization?).to be_falsey
        # claiming with organization
        expect { bike_sticker2.claim(user: user, bike: bike1, organization: organization) }.to change(BikeStickerUpdate, :count).by 1
        bike_sticker2.reload
        expect(bike_sticker2.claimed?).to be_truthy
        expect(bike_sticker2.user).to eq user
        expect(bike_sticker2.secondary_organization).to eq organization_paid
        bike_sticker_update4 = bike_sticker2.bike_sticker_updates.last
        expect(bike_sticker_update4.user).to eq user
        expect(bike_sticker_update4.organization).to eq organization_paid
        expect(bike_sticker_update4.bike).to be_blank
        expect(bike_sticker_update4.organization_kind).to eq "other_paid_organization"
        expect(bike_sticker_update4.unauthorized_organization?).to be_falsey
        # and user only has 1 unorganized update
        user.reload
        expect(user.unauthorized_organization_update_bike_sticker_ids).to match_array([bike_sticker1.id])
      end
    end
    # let(:ownership) { FactoryBot.create(:ownership) }
    # let(:bike) { ownership.bike }
    # let(:user) { FactoryBot.create(:user) }
    # let(:bike_sticker) { FactoryBot.create(:bike_sticker) }
    # it "claims, doesn't update when unable to parse" do
    #   bike_sticker.reload
    #   expect(bike_sticker.authorized?(user)).to be_truthy
    #   bike_sticker.claim(user: user, bike_or_string: bike.id)
    #   expect(bike_sticker.authorized?(user)).to be_truthy
    #   expect(bike_sticker.previous_bike_id).to be_nil
    #   expect(bike_sticker.user).to eq user
    #   expect(bike_sticker.bike).to eq bike
    #   bike_sticker.claim(user: user, bike_or_string: "https://bikeindex.org/bikes/9#{bike.id}")
    #   expect(bike_sticker.previous_bike_id).to be_nil
    #   expect(bike_sticker.errors.full_messages).to be_present
    #   expect(bike_sticker.bike).to eq bike
    #   bike_sticker.claim(user: user, bike_or_string: "https://bikeindex.org/bikes?per_page=200")
    #   expect(bike_sticker.errors.full_messages).to be_present
    #   expect(bike_sticker.bike).to eq bike
    #   expect(bike_sticker.claimed_at).to be_within(1.second).of Time.current
    #   expect(bike_sticker.previous_bike_id).to be_nil
    #   reloaded_code = BikeSticker.find bike_sticker.id # Hard reload, it wasn't resetting errors
    #   expect(reloaded_code.authorized?(user)).to be_truthy
    #   expect(reloaded_code.unclaimable_by?(user)).to be_truthy
    #   expect(ownership.creator.authorized?(bike)).to be_truthy
    #   expect(reloaded_code.unclaimable_by?(ownership.creator)).to be_truthy
    #   reloaded_code.claim(user: ownership.creator, bike_or_string: "")
    #   expect(reloaded_code.bike_id).to be_nil
    #   expect(reloaded_code.previous_bike_id).to eq bike.id
    # end
    # context "with weird strings" do
    #   it "updates" do
    #     bike_sticker.claim(user: user, "\nwww.bikeindex.org/bikes/#{bike.id}/edit")
    #     expect(bike_sticker.errors.full_messages).to_not be_present
    #     expect(bike_sticker.bike).to eq bike
    #     bike_sticker.claim(user: user, "\nwww.bikeindex.org/bikes/#{bike.id} ")
    #     expect(bike_sticker.errors.full_messages).to_not be_present
    #     expect(bike_sticker.bike).to eq bike
    #     expect(bike_sticker.previous_bike_id).to eq bike.id
    #   end
    # end
  end

  #   context "organized" do
  #     let(:organization) { FactoryBot.create(:organization) }
  #     let(:user) { FactoryBot.create(:organization_member, organization: organization) }
  #     let(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization) }
  #     it "permits unclaiming of organized bikes if already claimed" do
  #       expect(bike.organizations).to eq([])
  #       bike_sticker.claim(user: user, bike_or_string: bike)
  #       bike.reload
  #       bike_sticker.reload
  #       expect(bike.organizations.pluck(:id)).to eq([organization.id])
  #       expect(bike.can_edit_claimed_organizations.pluck(:id)).to eq([])
  #       expect(bike_sticker.claimed?).to be_truthy
  #       expect(bike_sticker.errors.full_messages).to_not be_present
  #       bike_sticker.claim(user: user, bike_or_string: "\n ")
  #       expect(bike_sticker.errors.full_messages).to_not be_present
  #       expect(bike_sticker.bike_id).to be_nil
  #       expect(bike_sticker.claimed_at).to be_nil
  #       expect(bike_sticker.user_id).to be_nil
  #       # Since no bike is assigned, it isn't unclaimable again
  #       bike_sticker.claim(user: user, bike_or_string: "\n ")
  #       expect(bike_sticker.errors.full_messages).to be_present
  #       # And it sets previous_bike_id correctly
  #       bike_sticker.reload
  #       bike_sticker.claim(user: user, bike_or_string: "")
  #       bike_sticker.reload
  #       expect(bike_sticker.previous_bike_id).to eq bike.id
  #       bike_sticker.reload
  #       bike_sticker.claim(user: user, bike_or_string: "")
  #       bike_sticker.reload
  #       expect(bike_sticker.previous_bike_id).to eq bike.id
  #     end
  #     context "unclaiming with bikeindex.org url" do
  #       let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike, organization: organization) }
  #       it "adds an error" do
  #         expect(bike_sticker.bike).to eq bike
  #         # Doesn't permit unclaiming by a bikeindex.org/ url, because that's probably a mistake
  #         bike_sticker.claim(user: user, bike_or_string: "www.bikeindex.org/bikes/ ")
  #         expect(bike_sticker.errors.full_messages).to be_present
  #         expect(bike_sticker.bike).to eq bike
  #       end
  #     end

  #     context "unorganized" do
  #       let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike, organization: FactoryBot.create(:organization)) }
  #       it "can't unclaim other orgs bikes" do
  #         bike_sticker.claim(user: user, bike_or_string: nil)
  #         expect(bike_sticker.errors.full_messages).to be_present
  #         expect(bike_sticker.claimed?).to be_truthy
  #         expect(bike_sticker.bike).to eq bike
  #       end
  #     end
  #   end
  # end

  # claim_if_permitted:
  # passing organization user isn't authorized on works

  # describe "authorized?" do
  #   context "organization" do
  #     let(:organization) { FactoryBot.create(:organization) }
  #     let!(:organization_member) { FactoryBot.create(:organization_member, organization: organization) }
  #     let(:ownership) { FactoryBot.create(:ownership) }
  #     let(:bike) { ownership.bike }
  #     let(:owner) { ownership.creator }
  #     let(:bike_sticker_user) { FactoryBot.create(:user_confirmed) }
  #     let(:admin) { User.new(superuser: true) }
  #     let(:rando) { FactoryBot.create(:user_confirmed) }
  #     let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike, organization: organization, user: bike_sticker_user) }
  #     it "is truthy for admins and org members and code claimer" do
  #       # Sanity Check organization authorizations
  #       expect(bike_sticker_user.authorized?(organization)).to be_falsey
  #       expect(owner.authorized?(organization)).to be_falsey
  #       expect(organization_member.authorized?(organization)).to be_truthy
  #       expect(admin.authorized?(organization)).to be_truthy
  #       expect(rando.authorized?(organization)).to be_falsey
  #       # Sanity check bike authorizations
  #       expect(bike.authorized?(bike_sticker_user)).to be_falsey
  #       expect(bike.authorized?(owner)).to be_truthy
  #       expect(bike.authorized?(organization_member)).to be_falsey
  #       expect(bike.authorized?(admin)).to be_falsey
  #       expect(bike.authorized?(rando)).to be_falsey
  #       # Check authorizations on the code itself
  #       expect(bike_sticker.authorized?(bike_sticker_user)).to be_truthy
  #       expect(bike_sticker.authorized?(owner)).to be_truthy
  #       expect(bike_sticker.authorized?(organization_member)).to be_truthy
  #       expect(bike_sticker.authorized?(admin)).to be_truthy
  #       expect(bike_sticker.authorized?(rando)).to be_falsey
  #       expect(bike_sticker.authorized?(User.new)).to be_falsey
  #     end
  #   end
  #   context "unclaimed bike_sticker" do
  #     let(:bike) { FactoryBot.create(:bike) }
  #     let(:bike_sticker) { FactoryBot.create(:bike_sticker) }
  #     let(:user) { FactoryBot.create(:user_confirmed) }
  #     it "permits user to authorize" do
  #       expect(bike_sticker.claimable_by?(user)).to be_truthy
  #       expect(bike_sticker.authorized?(user)).to be_truthy
  #       expect(user.authorized?(bike_sticker)).to be_truthy
  #       expect(User.new.authorized?(bike_sticker)).to be_truthy
  #       # User has claimed max claimable bike codes
  #       BikeSticker::MAX_UNORGANIZED.times { FactoryBot.create(:bike_sticker_claimed, bike: bike, user: user) }
  #       expect(bike_sticker.claimable_by?(user)).to be_falsey
  #       expect(bike_sticker.authorized?(user)).to be_falsey
  #       expect(user.authorized?(bike_sticker)).to be_falsey
  #       expect(User.new.authorized?(bike_sticker)).to be_truthy
  #     end
  #   end
  # end
end

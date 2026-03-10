require "rails_helper"

RSpec.describe ShopMachineModel, type: :model do
  describe "validations" do
    it "is valid with shop and machine" do
      smm = ShopMachineModel.new(shop: create(:shop), machine_model: create(:machine_model))
      expect(smm).to be_valid
    end

    it "enforces uniqueness per shop and machine" do
      shop = create(:shop)
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)

      duplicate = ShopMachineModel.new(shop: shop, machine_model: machine)
      expect(duplicate).not_to be_valid
    end

    it "allows same machine at different shops" do
      machine = create(:machine_model)
      shop1 = create(:shop)
      shop2 = create(:shop)
      ShopMachineModel.create!(shop: shop1, machine_model: machine)

      smm = ShopMachineModel.new(shop: shop2, machine_model: machine)
      expect(smm).to be_valid
    end

    it "allows different machines at same shop" do
      shop = create(:shop)
      machine1 = create(:machine_model)
      machine2 = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine1)

      smm = ShopMachineModel.new(shop: shop, machine_model: machine2)
      expect(smm).to be_valid
    end
  end

  describe "associations" do
    it "belongs to shop" do
      smm = ShopMachineModel.new(shop: create(:shop), machine_model: create(:machine_model))
      expect(smm.shop).to be_a(Shop)
    end

    it "belongs to machine_model" do
      smm = ShopMachineModel.new(shop: create(:shop), machine_model: create(:machine_model))
      expect(smm.machine_model).to be_a(MachineModel)
    end
  end

  describe "unit_count" do
    it "stores unit_count" do
      smm = ShopMachineModel.create!(shop: create(:shop), machine_model: create(:machine_model), unit_count: 10)
      smm.reload
      expect(smm.unit_count).to eq(10)
    end

    it "allows nil unit_count" do
      smm = ShopMachineModel.create!(shop: create(:shop), machine_model: create(:machine_model), unit_count: nil)
      expect(smm.unit_count).to be_nil
    end
  end
end

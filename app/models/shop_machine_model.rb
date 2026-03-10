class ShopMachineModel < ApplicationRecord
  belongs_to :shop
  belongs_to :machine_model

  validates :machine_model_id, uniqueness: { scope: :shop_id }
end

class AddTrackingIdToSpreeShipments < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :tracking_id, :string
  end
end

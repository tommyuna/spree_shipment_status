class AddNewColumnsToSpreeShipments < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :json_store_order_id, :json
    add_column :spree_shipments, :json_us_tracking_id, :json
    add_column :spree_shipments, :forwarding_id, :string
  end
end

class AddAfterShippedStateToSpreeShipments < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :after_shipped_state, :string
  end
end

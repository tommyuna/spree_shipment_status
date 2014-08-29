Deface::Override.new( :virtual_path => 'spree/admin/orders/_shipment',
                      :name         => 'add_after_shipped_state_dropdown',
                      :insert_before=> 'table[data-hook=stock-contents]',
                      :partial      => 'spree/admin/orders/after_shipped_state',
                      :disabled     => false)

Deface::Override.new( :virtual_path => 'spree/users/show',
                      :name         => 'replace_user_shipment_status',
                :replace_contents   => '.order-status',
                      :partial      => 'spree/users/user_shipment_status',
                      :disabled     => false)

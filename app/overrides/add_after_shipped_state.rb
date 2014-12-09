Deface::Override.new( :virtual_path => 'spree/admin/orders/_shipment',
                      :name         => 'add_after_shipped_state_dropdown',
                      :insert_before=> 'table[data-hook=stock-contents]',
                      :partial      => 'spree/admin/orders/after_shipped_state',
                      :disabled     => false,
                      :original => '3ac58e53b083210a2a0a996e7b3daeca524a3916')

Deface::Override.new( :virtual_path => 'spree/users/show',
                      :name         => 'replace_user_shipment_status',
                :replace_contents   => '.order-status',
                      :partial      => 'spree/users/user_shipment_status',
                      :disabled     => false,
                      :original     => '2f8bd13533d9b816d47609e84c30bc80ed57e4b6')

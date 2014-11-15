Spree::Shipment.class_eval do
  scope :before_ship,             -> { with_state('before_ship') }
  scope :local_delivery,          -> { with_state('local_delivery') }
  scope :local_delivery_complete, -> { with_state('local_delivery_complete') }
  scope :overseas_delivery,       -> { with_state('overseas_delivery') }
  scope :customs,                 -> { with_state('customs') }
  scope :domestic_delivery,       -> { with_state('domestic_delivery') }
  scope :delivered,               -> { with_state('delivered') }


  state_machine   :after_shipped_state,   :initial  => :before_ship do

    before_transition :from => :before_ship, :do => :check_ship
    after_transition :from => :before_ship, :do => :publish?

    event :complete_ship do
      transition from: :before_ship, to: :local_delivery
    end
    event :complete_local_delivery do
      transition from: [:before_ship, :local_delivery], to: :local_delivery_complete
    end
    event :start_oversea_delivery do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete], to: :overseas_delivery
    end
    event :complete_oversea_delivery do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete, :overseas_delivery], to: :customs
    end
    event :start_domestic_delivery do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete, :overseas_delivery, :customs], to: :domestic_delivery
    end
    event :complete_domestic_delivery do
      transition from: [:before_ship, :local_delivery, :local_delivery_complete, :overseas_delivery, :customs, :domestic_delivery], to: :delivered
    end
    event :backward_previous_after_shipped_state do
      transition  :delivered => :domestic_delivery,
                  :domestic_delivery => :customs,
                  :customs => :overseas_delivery,
                  :overseas_delivery => :local_delivery_complete,
                  :local_delivery_complete => :local_delivery,
                  :local_delivery => :before_ship
    end
  end   #state_machine

  def check_ship
    Rails.logger.info "shipment[#{self.id}] state[#{self.state}]"
    if self.state != 'shipped'
      if self.state == 'pending'
        self.order.payments.each do |p|
          Rails.logger.info "payment[#{p.id}] state[#{p.state}]"
          p.capture! if p.state == 'pending'
        end
      end
      self.reload
      return self.ship!
    end
    true
  end

  #deploy it next time
  def publish?
    #Rails.logger.info "publish?#{self}"
    #return if self.order.shipments.any? {|sh| not sh.shipped? }
    #Message::Shipment::ShipmentShipped.new(self.order.shipments)
    #Amqp::produce(msg,'shipping_automator')
    #true
  end

  def after_ship
    inventory_units.each &:ship!
    send_shipped_email
    touch :shipped_at
    update_order_shipment_state
    self.complete_ship!
  end

  def all_shipped?
    return false if self.json_store_order_id.nil?
    self.json_store_order_id.each do |store, order_ids|
      return false if self.json_us_tracking_id.nil? or self.json_us_tracking_id.empty?
      return false if self.json_us_tracking_id[store].nil? or self.json_us_tracking_id[store].empty?
      order_ids.each do |order_id|
        return false if self.json_us_tracking_id[store][order_id].nil? or self.json_us_tracking_id[store][order_id].empty?
      end
    end
  end

  def push_store_order_id store, order_id
    store_order_id = self.json_store_order_id
    us_tracking_id = self.json_us_tracking_id
    store_order_id = {} if store_order_id.nil?
    us_tracking_id = {} if us_tracking_id.nil?
    if store_order_id[store].nil?
      store_order_id[store] = []
      us_tracking_id[store] = {}
    end
    store_order_id[store].push order_id
    us_tracking_id[store][order_id] = [] if us_tracking_id[store][order_id].nil?
    self.update_attributes({:json_store_order_id => store_order_id, :json_us_tracking_id => us_tracking_id})
  end
  def push_us_tracking_id store, order_id, us_tracking_ids
    return if store.nil? or order_id.nil? or us_tracking_ids.nil?
    us_tracking_id = self.json_us_tracking_id
    us_tracking_id = {} if us_tracking_id.nil?
    us_tracking_id[store] = {} if us_tracking_id[store].nil?
    us_tracking_id[store][order_id] = [] if us_tracking_id[store][order_id].nil?
    us_tracking_id[store][order_id] = us_tracking_ids
    self.update_columns(:json_us_tracking_id => us_tracking_id)
  end
  def get_store_urls
    return [] if self.store.nil?
    urls = []
    self.store.split(",").each do |store|
      case store
      when 'amazon'
        urls.push 'www.amazon.com'
      when 'ssense'
        urls.push 'www.ssense.com'
      when 'gap'
        urls.push 'www.gap.com'
      when 'bananarepublic'
        urls.push 'www.bananarepublic.com'
      else
        urls.push store
      end
    end
    urls
  end

  def get_shipment_status
    if self.canceled?
      return "canceled"
    else
      return self.after_shipped_state
    end
  end

end   #class_eval

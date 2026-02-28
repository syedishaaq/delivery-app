# delivery-app
just for backend purpose
# QuickBite - Mobile Food Delivery App

## Current State
New project. No existing code.

## Requested Changes (Diff)

### Add
- Three-role system: Owner, Customer, Delivery Boy
- Role-based login/dashboard routing
- Menu management (Owner can add/edit food items)
- Customer order flow: browse menu, add to cart, place order
- Owner dashboard: live order stats, all orders list, revenue summary
- Delivery dashboard: assigned orders, mark order as picked up / delivered
- Order status tracking: Pending -> Accepted -> Picked Up -> Delivered
- Sample food menu with categories (Burgers, Pizza, Drinks, etc.)

### Modify
- N/A (new project)

### Remove
- N/A (new project)

## Implementation Plan

### Backend (Motoko)
1. Data models: User (id, name, role: #owner | #customer | #delivery), FoodItem (id, name, category, price, description, imageUrl), Order (id, customerId, deliveryBoyId, items, total, status, createdAt), CartItem
2. Auth: login with name + role selection (no real auth, demo-mode)
3. Food: getMenu, addFoodItem, updateFoodItem
4. Orders: placeOrder, getOrdersByCustomer, getAllOrders (owner), getAssignedOrders (delivery), updateOrderStatus, assignDeliveryBoy
5. Stats: getTotalOrders, getOrderCountByStatus, getTotalRevenue

### Frontend
1. Role selection / login screen (pick role: Owner / Customer / Delivery Boy + enter name)
2. Customer view: food menu grid with categories filter, cart drawer, order placement, order history
3. Owner view: dashboard with stats cards (total orders, pending, delivered, revenue), orders table with status, ability to accept orders and assign delivery boy
4. Delivery view: list of assigned orders, status update buttons (Picked Up, Delivered), order details
5. Shared: order status badge, responsive mobile-first layout, smooth navigation between screens

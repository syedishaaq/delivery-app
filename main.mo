import List "mo:core/List";
import Set "mo:core/Set";
import Map "mo:core/Map";
import Array "mo:core/Array";
import Order "mo:core/Order";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Timer "mo:core/Timer";
import Principal "mo:core/Principal";
import Runtime "mo:core/Runtime";
import MixinAuthorization "authorization/MixinAuthorization";
import AccessControl "authorization/access-control";

actor {
  // Initialize the access control system
  let accessControlState = AccessControl.initState();
  include MixinAuthorization(accessControlState);

  module FoodItem {
    public func compare(foodItem1 : FoodItem, foodItem2 : FoodItem) : Order.Order {
      switch (Text.compare(foodItem1.category, foodItem2.category)) {
        case (#equal) { Text.compare(foodItem1.name, foodItem2.name) };
        case (order) { order };
      };
    };
  };

  type Role = {
    #owner;
    #customer;
    #deliveryBoy;
  };

  type User = {
    id : Principal;
    name : Text;
    role : Role;
  };

  type UserProfile = {
    name : Text;
    role : Role;
  };

  type FoodItem = {
    id : Nat;
    name : Text;
    category : Text;
    price : Nat;
    description : Text;
    available : Bool;
  };

  type CartItem = {
    foodItemId : Nat;
    name : Text;
    quantity : Nat;
    price : Nat;
  };

  type OrderStatus = {
    #pending;
    #accepted;
    #pickedUp;
    #delivered;
    #cancelled;
  };

  type Order = {
    id : Nat;
    customerId : Principal;
    customerName : Text;
    deliveryBoyId : ?Principal;
    items : [CartItem];
    totalAmount : Nat;
    status : OrderStatus;
    createdAt : Int;
  };

  // Internal State
  var nextFoodItemId = 1;
  var nextOrderId = 1;
  let users = Map.empty<Principal, User>();
  let userProfiles = Map.empty<Principal, UserProfile>();
  let foodItems = Map.empty<Nat, FoodItem>();
  let orders = Map.empty<Nat, Order>();

  // Persistent cart state for each user
  let carts = Map.empty<Principal, List.List<CartItem>>();

  // Helper function to check if user has a specific app role
  func hasAppRole(caller : Principal, requiredRole : Role) : Bool {
    switch (users.get(caller)) {
      case (?user) {
        switch (user.role, requiredRole) {
          case (#owner, #owner) { true };
          case (#customer, #customer) { true };
          case (#deliveryBoy, #deliveryBoy) { true };
          case (_, _) { false };
        };
      };
      case (null) { false };
    };
  };

  // Initialize with sample data
  func init() {
    // Seed sample food items
    let burgerItem : FoodItem = {
      id = nextFoodItemId;
      name = "Classic Burger";
      category = "burgers";
      price = 899;
      description = "Juicy beef patty with lettuce, tomato, and special sauce";
      available = true;
    };
    foodItems.add(nextFoodItemId, burgerItem);
    nextFoodItemId += 1;

    let pizzaItem : FoodItem = {
      id = nextFoodItemId;
      name = "Margherita Pizza";
      category = "pizza";
      price = 1299;
      description = "Fresh mozzarella, tomato sauce, and basil";
      available = true;
    };
    foodItems.add(nextFoodItemId, pizzaItem);
    nextFoodItemId += 1;

    let drinkItem : FoodItem = {
      id = nextFoodItemId;
      name = "Cola";
      category = "drinks";
      price = 199;
      description = "Refreshing cola drink";
      available = true;
    };
    foodItems.add(nextFoodItemId, drinkItem);
    nextFoodItemId += 1;

    let sidesItem : FoodItem = {
      id = nextFoodItemId;
      name = "French Fries";
      category = "sides";
      price = 399;
      description = "Crispy golden fries";
      available = true;
    };
    foodItems.add(nextFoodItemId, sidesItem);
    nextFoodItemId += 1;
  };

  init();

  // User Profile Management (required by instructions)
  public query ({ caller }) func getCallerUserProfile() : async ?UserProfile {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can view profiles");
    };
    userProfiles.get(caller);
  };

  public query ({ caller }) func getUserProfile(user : Principal) : async ?UserProfile {
    if (caller != user and not AccessControl.isAdmin(accessControlState, caller)) {
      Runtime.trap("Unauthorized: Can only view your own profile");
    };
    userProfiles.get(user);
  };

  public shared ({ caller }) func saveCallerUserProfile(profile : UserProfile) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can save profiles");
    };
    userProfiles.add(caller, profile);
  };

  // Authentication - accessible to anyone (guests)
  public shared ({ caller }) func loginAs(name : Text, role : Role) : async Principal {
    let userId = caller;
    let user : User = {
      id = userId;
      name;
      role;
    };
    users.add(userId, user);

    // Map app roles to AccessControl roles
    let accessRole = switch (role) {
      case (#owner) { #admin };
      case (#customer) { #user };
      case (#deliveryBoy) { #user };
    };

    // Assign the appropriate access control role
    AccessControl.assignRole(accessControlState, caller, userId, accessRole);

    // Also save user profile
    let profile : UserProfile = {
      name;
      role;
    };
    userProfiles.add(userId, profile);

    userId;
  };

  // Requires authentication
  public query ({ caller }) func getCurrentUser() : async User {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can view their profile");
    };
    switch (users.get(caller)) {
      case (?user) { user };
      case (null) { Runtime.trap("User not found") };
    };
  };

  // Public - accessible to anyone including guests
  public query ({ caller }) func getMenu() : async [FoodItem] {
    let availableItems = List.empty<FoodItem>();
    for (item in foodItems.values()) {
      if (item.available) {
        availableItems.add(item);
      };
    };
    availableItems.toArray().sort();
  };

  // Requires authentication (customers)
  public shared ({ caller }) func addToCart(cartItem : CartItem) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can add to cart");
    };
    if (not hasAppRole(caller, #customer)) {
      Runtime.trap("Unauthorized: Only customers can add to cart");
    };

    let currentCart = switch (carts.get(caller)) {
      case (?cart) { cart };
      case (null) {
        let cart = List.empty<CartItem>();
        carts.add(caller, cart);
        cart;
      };
    };
    currentCart.add(cartItem);
  };

  // Requires authentication (customers)
  public query ({ caller }) func getCart() : async [CartItem] {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can view cart");
    };
    if (not hasAppRole(caller, #customer)) {
      Runtime.trap("Unauthorized: Only customers can view cart");
    };

    switch (carts.get(caller)) {
      case (?cart) { cart.toArray() };
      case (null) { [] };
    };
  };

  // Requires authentication (customers only)
  public shared ({ caller }) func placeOrder() : async Nat {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can place orders");
    };
    if (not hasAppRole(caller, #customer)) {
      Runtime.trap("Unauthorized: Only customers can place orders");
    };

    let cart = switch (carts.get(caller)) {
      case (?cart) { cart };
      case (null) { Runtime.trap("Cart not found") };
    };

    if (cart.size() == 0) {
      Runtime.trap("Cannot place order with empty cart");
    };

    let customerName = switch (users.get(caller)) {
      case (?user) { user.name };
      case (null) { "" };
    };

    let totalAmount = cart.foldLeft(
      0,
      func(acc, item) { acc + item.price * item.quantity },
    );

    let order : Order = {
      id = nextOrderId;
      customerId = caller;
      customerName;
      deliveryBoyId = null;
      items = cart.toArray();
      totalAmount;
      status = #pending;
      createdAt = 0;
    };

    orders.add(nextOrderId, order);
    carts.remove(caller);
    let orderId = nextOrderId;
    nextOrderId += 1;
    orderId;
  };

  // Owner only
  public shared ({ caller }) func addFoodItem(name : Text, category : Text, price : Nat, description : Text) : async Nat {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only owners can add food items");
    };
    if (not hasAppRole(caller, #owner)) {
      Runtime.trap("Unauthorized: Only owners can add food items");
    };

    let foodItem : FoodItem = {
      id = nextFoodItemId;
      name;
      category;
      price;
      description;
      available = true;
    };
    foodItems.add(nextFoodItemId, foodItem);
    let itemId = nextFoodItemId;
    nextFoodItemId += 1;
    itemId;
  };

  // Owner only
  public shared ({ caller }) func updateFoodItem(id : Nat, name : Text, category : Text, price : Nat, description : Text, available : Bool) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only owners can update food items");
    };
    if (not hasAppRole(caller, #owner)) {
      Runtime.trap("Unauthorized: Only owners can update food items");
    };

    switch (foodItems.get(id)) {
      case (null) { Runtime.trap("Food item not found") };
      case (?_) {
        let updatedItem : FoodItem = {
          id;
          name;
          category;
          price;
          description;
          available;
        };
        foodItems.add(id, updatedItem);
      };
    };
  };

  // Owner only - for assigning delivery boys to orders
  public query ({ caller }) func getDeliveryBoys() : async [User] {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only owners can view delivery boys");
    };
    if (not hasAppRole(caller, #owner)) {
      Runtime.trap("Unauthorized: Only owners can view delivery boys");
    };

    let deliveryBoys = List.empty<User>();
    for (user in users.values()) {
      switch (user.role) {
        case (#deliveryBoy) { deliveryBoys.add(user) };
        case (_) {};
      };
    };
    deliveryBoys.toArray();
  };

  // Customer only - view their own orders
  public query ({ caller }) func getMyOrders() : async [Order] {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can view orders");
    };
    if (not hasAppRole(caller, #customer)) {
      Runtime.trap("Unauthorized: Only customers can view their orders");
    };

    let myOrders = List.empty<Order>();
    for (order in orders.values()) {
      if (order.customerId == caller) {
        myOrders.add(order);
      };
    };
    myOrders.toArray();
  };

  // Owner only - view all orders
  public query ({ caller }) func getAllOrders() : async [Order] {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only owners can view all orders");
    };
    if (not hasAppRole(caller, #owner)) {
      Runtime.trap("Unauthorized: Only owners can view all orders");
    };

    let allOrders = List.empty<Order>();
    for (order in orders.values()) {
      allOrders.add(order);
    };
    allOrders.toArray();
  };

  // Delivery boy only - view assigned orders
  public query ({ caller }) func getAssignedOrders() : async [Order] {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can view orders");
    };
    if (not hasAppRole(caller, #deliveryBoy)) {
      Runtime.trap("Unauthorized: Only delivery boys can view assigned orders");
    };

    let assignedOrders = List.empty<Order>();
    for (order in orders.values()) {
      switch (order.deliveryBoyId) {
        case (?deliveryBoyId) {
          if (deliveryBoyId == caller) {
            assignedOrders.add(order);
          };
        };
        case (null) {};
      };
    };
    assignedOrders.toArray();
  };

  // Owner only - assign delivery boy to order
  public shared ({ caller }) func acceptOrder(orderId : Nat, deliveryBoyId : Principal) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only owners can accept orders");
    };
    if (not hasAppRole(caller, #owner)) {
      Runtime.trap("Unauthorized: Only owners can accept orders");
    };

    // Verify delivery boy exists and has correct role
    switch (users.get(deliveryBoyId)) {
      case (?user) {
        if (not hasAppRole(deliveryBoyId, #deliveryBoy)) {
          Runtime.trap("Invalid delivery boy: User is not a delivery boy");
        };
      };
      case (null) {
        Runtime.trap("Delivery boy not found");
      };
    };

    switch (orders.get(orderId)) {
      case (null) { Runtime.trap("Order not found") };
      case (?order) {
        let updatedOrder : Order = {
          id = order.id;
          customerId = order.customerId;
          customerName = order.customerName;
          deliveryBoyId = ?deliveryBoyId;
          items = order.items;
          totalAmount = order.totalAmount;
          status = #accepted;
          createdAt = order.createdAt;
        };
        orders.add(orderId, updatedOrder);
      };
    };
  };

  // Delivery boy only - update order status
  public shared ({ caller }) func updateOrderStatus(orderId : Nat, status : OrderStatus) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can update order status");
    };
    if (not hasAppRole(caller, #deliveryBoy)) {
      Runtime.trap("Unauthorized: Only delivery boys can update order status");
    };

    switch (orders.get(orderId)) {
      case (null) { Runtime.trap("Order not found") };
      case (?order) {
        // Verify this delivery boy is assigned to this order
        switch (order.deliveryBoyId) {
          case (?deliveryBoyId) {
            if (deliveryBoyId != caller) {
              Runtime.trap("Unauthorized: You are not assigned to this order");
            };
          };
          case (null) {
            Runtime.trap("Order has no assigned delivery boy");
          };
        };

        // Only allow certain status transitions
        switch (status) {
          case (#pickedUp) {};
          case (#delivered) {};
          case (_) {
            Runtime.trap("Invalid status: Delivery boys can only set status to pickedUp or delivered");
          };
        };

        let updatedOrder : Order = {
          id = order.id;
          customerId = order.customerId;
          customerName = order.customerName;
          deliveryBoyId = order.deliveryBoyId;
          items = order.items;
          totalAmount = order.totalAmount;
          status;
          createdAt = order.createdAt;
        };
        orders.add(orderId, updatedOrder);
      };
    };
  };

  // Owner only - get total number of orders
  public query ({ caller }) func getTotalOrders() : async Nat {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only owners can view statistics");
    };
    if (not hasAppRole(caller, #owner)) {
      Runtime.trap("Unauthorized: Only owners can view statistics");
    };

    orders.size();
  };

  // Owner only - get orders by status
  public query ({ caller }) func getOrdersByStatus(status : OrderStatus) : async [Order] {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only owners can view statistics");
    };
    if (not hasAppRole(caller, #owner)) {
      Runtime.trap("Unauthorized: Only owners can view statistics");
    };

    let filteredOrders = List.empty<Order>();
    for (order in orders.values()) {
      if (order.status == status) {
        filteredOrders.add(order);
      };
    };
    filteredOrders.toArray();
  };

  // Owner only - get total revenue
  public query ({ caller }) func getTotalRevenue() : async Nat {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only owners can view statistics");
    };
    if (not hasAppRole(caller, #owner)) {
      Runtime.trap("Unauthorized: Only owners can view statistics");
    };

    var totalRevenue = 0;
    for (order in orders.values()) {
      switch (order.status) {
        case (#delivered) {
          totalRevenue += order.totalAmount;
        };
        case (_) {};
      };
    };
    totalRevenue;
  };
};

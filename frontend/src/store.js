/**
 * @file store.js
 * @description Redux Store Configuration.
 * Combines all reducers, applies middleware (Thunk), and initializes the store.
 * Also handles persistence of Cart and User Info using Cookies.
 */

import { createStore, combineReducers, applyMiddleware, compose } from 'redux';
import thunk from 'redux-thunk';
import Cookie from 'js-cookie';
import {
  productListReducer,
  productDetailsReducer,
  productSaveReducer,
  productDeleteReducer,
  productReviewSaveReducer,
} from './reducers/productReducers';
import { cartReducer } from './reducers/cartReducers';
import {
  userSigninReducer,
  userRegisterReducer,
  userUpdateReducer,
} from './reducers/userReducers';
import {
  orderCreateReducer,
  orderDetailsReducer,
  orderPayReducer,
  myOrderListReducer,
  orderListReducer,
  orderDeleteReducer,
} from './reducers/orderReducers';

// ----------------------------------------------------------------------------
// Initial State & Persistence
// ----------------------------------------------------------------------------
// Load cart items and user info from cookies to persist state across reloads
const cartItems = Cookie.get('cartItems') ? JSON.parse(Cookie.get('cartItems')) : [];
const userInfo = Cookie.get('userInfo') ? JSON.parse(Cookie.get('userInfo')) : null;

// Ensure cartItems is always an array
const safeCartItems = Array.isArray(cartItems) ? cartItems : [];

const initialState = {
  cart: { cartItems: safeCartItems, shipping: {}, payment: {} },
  userSignin: { userInfo },
};

// ----------------------------------------------------------------------------
// Reducer Combination
// ----------------------------------------------------------------------------
const reducer = combineReducers({
  productList: productListReducer,
  productDetails: productDetailsReducer,
  cart: cartReducer,
  userSignin: userSigninReducer,
  userRegister: userRegisterReducer,
  productSave: productSaveReducer,
  productDelete: productDeleteReducer,
  productReviewSave: productReviewSaveReducer,
  orderCreate: orderCreateReducer,
  orderDetails: orderDetailsReducer,
  orderPay: orderPayReducer,
  userUpdate: userUpdateReducer,
  myOrderList: myOrderListReducer,
  orderList: orderListReducer,
  orderDelete: orderDeleteReducer,
});

// ----------------------------------------------------------------------------
// Store Creation
// ----------------------------------------------------------------------------
const composeEnhancer = window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__ || compose;
const store = createStore(
  reducer,
  initialState,
  composeEnhancer(applyMiddleware(thunk))
);

export default store;


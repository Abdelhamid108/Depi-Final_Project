/**
 * @file orderRoute.js
 * @description API Routes for Order Management.
 * Handles creating, retrieving, deleting, and paying for orders.
 */

import express from 'express';
import mongoose from 'mongoose';
import Order from '../models/orderModel';
import { isAuth, isAdmin } from '../util';

const router = express.Router();

/**
 * @route   GET /api/orders
 * @desc    Get all orders (Admin only)
 * @access  Private (Admin)
 */
router.get("/", isAuth, async (req, res) => {
  const orders = await Order.find({}).populate('user');
  res.send(orders);
});

/**
 * @route   GET /api/orders/mine
 * @desc    Get logged-in user's orders
 * @access  Private
 */
router.get("/mine", isAuth, async (req, res) => {
  const orders = await Order.find({ user: req.user._id });
  res.send(orders);
});

/**
 * @route   GET /api/orders/:id
 * @desc    Get order by ID
 * @access  Private
 */
router.get("/:id", isAuth, async (req, res) => {
  try {
    // Validate if the id is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).send("Invalid order ID format.");
    }

    const order = await Order.findOne({ _id: req.params.id });
    if (order) {
      res.send(order);
    } else {
      res.status(404).send("Order Not Found.")
    }
  } catch (error) {
    console.error('Error fetching order:', error);
    res.status(500).send("Internal server error.");
  }
});

/**
 * @route   DELETE /api/orders/:id
 * @desc    Delete an order
 * @access  Private (Admin)
 */
router.delete("/:id", isAuth, isAdmin, async (req, res) => {
  try {
    // Validate if the id is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).send("Invalid order ID format.");
    }

    const order = await Order.findOne({ _id: req.params.id });
    if (order) {
      const deletedOrder = await order.remove();
      res.send(deletedOrder);
    } else {
      res.status(404).send("Order Not Found.")
    }
  } catch (error) {
    console.error('Error deleting order:', error);
    res.status(500).send("Internal server error.");
  }
});

/**
 * @route   POST /api/orders
 * @desc    Create a new order
 * @access  Private
 */
router.post("/", isAuth, async (req, res) => {
  const newOrder = new Order({
    orderItems: req.body.orderItems,
    user: req.user._id,
    shipping: req.body.shipping,
    payment: req.body.payment,
    itemsPrice: req.body.itemsPrice,
    taxPrice: req.body.taxPrice,
    shippingPrice: req.body.shippingPrice,
    totalPrice: req.body.totalPrice,
  });
  const newOrderCreated = await newOrder.save();
  res.status(201).send({ message: "New Order Created", data: newOrderCreated });
});

/**
 * @route   PUT /api/orders/:id/pay
 * @desc    Update order to paid status
 * @access  Private
 */
router.put("/:id/pay", isAuth, async (req, res) => {
  const order = await Order.findById(req.params.id);
  if (order) {
    order.isPaid = true;
    order.paidAt = Date.now();
    order.payment = {
      paymentMethod: 'paypal',
      paymentResult: {
        payerID: req.body.payerID,
        orderID: req.body.orderID,
        paymentID: req.body.paymentID
      }
    }
    const updatedOrder = await order.save();
    res.send({ message: 'Order Paid.', order: updatedOrder });
  } else {
    res.status(404).send({ message: 'Order not found.' })
  }
});

export default router;
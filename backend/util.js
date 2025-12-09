/**
 * @file util.js
 * @description Utility functions for authentication and authorization.
 */

import jwt from 'jsonwebtoken';
import config from './config';

/**
 * Generates a JSON Web Token (JWT) for a user.
 * @param {Object} user - The user object containing _id, name, email, and isAdmin status.
 * @returns {string} Signed JWT string valid for 48 hours.
 */
const getToken = (user) => {
  return jwt.sign(
    {
      _id: user._id,
      name: user.name,
      email: user.email,
      isAdmin: user.isAdmin,
    },
    config.JWT_SECRET,
    {
      expiresIn: '48h',
    }
  );
};

/**
 * Middleware to authenticate users via JWT.
 * Checks for the 'Authorization' header (Bearer token).
 * If valid, attaches the decoded user to req.user.
 * @param {Object} req - Express request object.
 * @param {Object} res - Express response object.
 * @param {Function} next - Express next middleware function.
 */
const isAuth = (req, res, next) => {
  const token = req.headers.authorization;

  if (token) {
    const onlyToken = token.slice(7, token.length);
    jwt.verify(onlyToken, config.JWT_SECRET, (err, decode) => {
      if (err) {
        return res.status(401).send({ message: 'Invalid Token' });
      }
      req.user = decode;
      next();
      return;
    });
  } else {
    return res.status(401).send({ message: 'Token is not supplied.' });
  }
};

/**
 * Middleware to authorize Admin users.
 * Must be used after isAuth middleware.
 * @param {Object} req - Express request object.
 * @param {Object} res - Express response object.
 * @param {Function} next - Express next middleware function.
 */
const isAdmin = (req, res, next) => {
  console.log(req.user);
  if (req.user && req.user.isAdmin) {
    return next();
  }
  return res.status(401).send({ message: 'Admin Token is not valid.' });
};

export { getToken, isAuth, isAdmin };


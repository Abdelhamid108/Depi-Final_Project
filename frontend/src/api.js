/**
 * @file api.js
 * @description Axios Instance Configuration.
 * Sets up the base URL and global interceptors for handling requests and responses.
 */

import axios from 'axios';

// Create an instance of axios with the base URL from environment variables
const apiUrl = process.env.REACT_APP_API_URL || '';
const api = axios.create({
  baseURL: apiUrl
});

// ----------------------------------------------------------------------------
// Interceptors
// ----------------------------------------------------------------------------

// Request Interceptor
api.interceptors.request.use(
  function (config) {
    // Do something before request is sent (e.g., attach tokens if not using cookies)
    return config;
  },
  function (error) {
    console.error('API Request Error:', error);
    return Promise.reject(error);
  }
);

// Response Interceptor
api.interceptors.response.use(
  function (response) {
    // Return response directly if successful (2xx status)
    return response;
  },
  function (error) {
    // Handle errors globally
    console.error('API Response Error:', error.response?.data?.message || error.message);

    if (error.response) {
      if (error.response.status === 401) {
        console.log('Authentication error - you may need to sign in again');
      } else if (error.response.status === 500) {
        console.log('Server error - please try again later');
      }
    } else if (error.request) {
      console.log('Network error - please check your connection');
    }

    return Promise.reject(error);
  }
);

export default api;


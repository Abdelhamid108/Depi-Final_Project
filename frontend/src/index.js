/**
 * @file index.js
 * @description Application Entry Point.
 * Renders the React App component into the DOM and provides the Redux Store.
 */

import React from 'react';
import { Provider } from 'react-redux';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';
import store from './store';

ReactDOM.render(
  <Provider store={store}>
    <App />
  </Provider>, document.getElementById('root'));



# Amazona - E-commerce Platform (Developer Documentation)

This document provides a detailed overview of the Amazona e-commerce project, its architecture, and setup instructions for local development.  
It is intended for developers who will be working with the source code.

---

## Project Overview

Amazona is a full-stack e-commerce web application built using the MERN stack (MongoDB, Express, React, Node.js).  
It serves as a practical example of a modern single-page e-commerce platform with both a customer-facing storefront and an admin management panel.

---

## Features

### Customer Features
- **Product Discovery:** Browse and search for products with keyword search. Filter by category or sort by price or newness.  
- **Shopping Cart:** Persistent shopping cart that saves items even after leaving the site.  
- **User Authentication:** Secure registration and login using JSON Web Tokens (JWT).  
- **Checkout Flow:** Multi-step checkout process including shipping address entry, payment method selection, and order summary.  
- **Payment Integration:** Pay for orders using the PayPal API.  
- **User Profile:** View order history and update profile information.

### Admin Features
- **Product Management:** Full CRUD (Create, Read, Update, Delete) operations for products.  
- **Order Management:** View and manage all customer orders.  
- **Image Uploads:** Upload product images, with support for local storage and AWS S3.

---

## Tech Stack

### Frontend
- **React:** Component-based architecture for reusable UI elements.  
- **Redux:** Global state management for user, product, and cart data.  
- **React Router:** Client-side routing for single-page application experience.  
- **Axios:** HTTP client for API requests.  
- **js-cookie:** For storing user session data in cookies.

### Backend
- **Node.js & Express.js:** RESTful API framework for routing, requests, and responses.  
- **MongoDB:** NoSQL database for storing product, user, and order data.  
- **Mongoose:** ODM library for data modeling and validation.  
- **JWT (JSON Web Tokens):** Secure authentication for users and admins.  
- **Multer:** Middleware for handling file uploads.  
- **AWS S3:** Optional cloud storage for images.

---

## Project Structure

```

/
├── backend/
│   ├── models/       # Mongoose schemas (e.g., productModel.js, userModel.js)
│   ├── routes/       # API route definitions (e.g., productRoute.js, userRoute.js)
│   ├── uploads/      # Default directory for local image uploads
│   ├── .env          # Environment variables for the server
│   └── server.js     # Main Express server entry point and configuration
│
└── frontend/
├── public/       # Static assets and index.html
└── src/
├── actions/      # Redux actions: API calls and dispatches
├── components/   # Reusable React components (e.g., Rating, CheckoutSteps)
├── constants/    # Redux action type constants
├── reducers/     # Redux reducers for state updates
├── screens/      # Page-level components (e.g., HomeScreen, ProductScreen)
└── store.js      # Redux store configuration

````

---

## State Management with Redux

The frontend uses Redux to manage global state.

**Data Flow:**
1. **Action:** User interacts with a React component (e.g., clicks "Add to Cart").  
2. **API Call:** The action creator makes an asynchronous API call to the backend.  
3. **Dispatch:** The action creator dispatches a new action with a type and payload.  
4. **Reducer:** The reducer updates the state based on the dispatched action.  
5. **Store Update:** The Redux store is updated with the new state.  
6. **Re-render:** Components subscribed to the store automatically re-render.

**Key Redux states:**
- `userSignin`
- `productList`
- `cart`

---

## Local Development Setup

### Prerequisites
- Node.js (version 18.x or higher)  
- MongoDB installed and running

---

### Environment Variables

Create a `.env` file in the `backend` directory and add the following:

```bash
# backend/.env
MONGODB_URL=mongodb://localhost:27017/amazona
JWT_SECRET=your_jwt_secret
PAYPAL_CLIENT_ID=sb

# Optional: AWS S3 Configuration
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=
AWS_BUCKET_NAME=
````

---

### Installation and Running the Application

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/amazona.git
cd amazona

# 2. Install backend dependencies
cd backend
npm install

# 3. Install frontend dependencies
cd ../frontend
npm install

# 4. Run the backend
cd ../backend
npm start

# 5. Run the frontend
cd ../frontend
npm start
```

The application will be available at **[http://localhost:3000](http://localhost:3000)**.

---

### Seeding the Database

To populate the database with sample data:

```bash
cd backend
npm run seed
```

---

## API Endpoints

All backend routes are prefixed with `/api`.

### Products

| Method     | Endpoint        | Description                                                             |
| ---------- | --------------- | ----------------------------------------------------------------------- |
| **GET**    | `/products`     | Fetch all products (supports filters, e.g. `/products?category=Shirts`) |
| **GET**    | `/products/:id` | Fetch a single product                                                  |
| **POST**   | `/products`     | Create a new product (Admin only)                                       |
| **PUT**    | `/products/:id` | Update an existing product (Admin only)                                 |
| **DELETE** | `/products/:id` | Delete a product (Admin only)                                           |

### Users

| Method   | Endpoint          | Description                                   |
| -------- | ----------------- | --------------------------------------------- |
| **POST** | `/users/signin`   | Authenticate a user and return JWT            |
| **POST** | `/users/register` | Register a new user                           |
| **PUT**  | `/users/:id`      | Update a user's profile (Authenticated users) |

### Orders

| Method   | Endpoint          | Description                              |
| -------- | ----------------- | ---------------------------------------- |
| **POST** | `/orders`         | Create a new order (Authenticated users) |
| **GET**  | `/orders/mine`    | Fetch the logged-in user's order history |
| **GET**  | `/orders/:id`     | Fetch details for a specific order       |
| **PUT**  | `/orders/:id/pay` | Mark an order as paid                    |

### Uploads

| Method   | Endpoint   | Description                        |
| -------- | ---------- | ---------------------------------- |
| **POST** | `/uploads` | Upload an image file for a product |

---

## Additional Notes

* The frontend communicates with the backend using Axios.
* Authentication and route protection are implemented using JWT tokens.
* Image uploads are stored locally in `/uploads` unless AWS S3 credentials are provided.

---

## Author

Amazona Developer Team
Built using the MERN Stack.

```

---

That’s the **entire documentation**, cleanly wrapped in one Markdown code block so you can paste it directly into a single `.md` file (like `README.md` or `DEVELOPER.md`) without breaking formatting.  

Would you like me to add a **table of contents with clickable links** (Markdown anchors) at the top for better navigation in GitHub?
```


import mongoose from 'mongoose';
import dotenv from 'dotenv';
import config from './config.js';
import Product from './models/productModel.js';

dotenv.config();

const sampleProducts = [
  {
    name: 'Nike Slim Shirt',
    image: '/images/p1.jpg',
    brand: 'Nike',
    price: 120,
    category: 'Shirts',
    countInStock: 10,
    description: 'High quality product',
    rating: 4.5,
    numReviews: 10,
  },
  {
    name: 'Adidas Fit Shirt',
    image: '/images/p2.jpg',
    brand: 'Adidas',
    price: 100,
    category: 'Shirts',
    countInStock: 20,
    description: 'High quality product',
    rating: 4.0,
    numReviews: 10,
  },
  {
    name: 'Lacoste Free Shirt',
    image: '/images/p3.jpg',
    brand: 'Lacoste',
    price: 220,
    category: 'Shirts',
    countInStock: 0,
    description: 'High quality product',
    rating: 4.8,
    numReviews: 17,
  },
  {
    name: 'Nike Slim Pant',
    image: '/images/d1.jpg',
    brand: 'Nike',
    price: 78,
    category: 'Pants',
    countInStock: 15,
    description: 'High quality product',
    rating: 4.5,
    numReviews: 14,
  },
  {
    name: 'Puma Slim Pant',
    image: '/images/d2.jpg',
    brand: 'Puma',
    price: 65,
    category: 'Pants',
    countInStock: 5,
    description: 'High quality product',
    rating: 4.5,
    numReviews: 10,
  },
  {
    name: 'Adidas Fit Pant',
    image: '/images/d3.jpg',
    brand: 'Adidas',
    price: 139,
    category: 'Pants',
    countInStock: 12,
    description: 'High quality product',
    rating: 4.5,
    numReviews: 15,
  },
];

const seedProducts = async () => {
  try {
    // Connect to MongoDB using a local connection (for direct seeding)
    const mongodbUrl = 'mongodb://admin:password@localhost:27017/amazona?authSource=admin';
    console.log('→ connecting to MongoDB at:', mongodbUrl);
    
    await mongoose.connect(mongodbUrl, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    
    console.log('Connected to MongoDB');
    
    // Clear existing products
    await Product.deleteMany({});
    console.log('Products cleared');
    
    // Insert sample products
    const createdProducts = await Product.insertMany(sampleProducts);
    console.log('Products added:', createdProducts.length);
    
    console.log('Data import completed successfully');
    process.exit();
  } catch (error) {
    console.error('Error seeding products:', error.message);
    process.exit(1);
  }
};

seedProducts();

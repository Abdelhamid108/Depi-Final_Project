import express from 'express';
import { S3Client, DeleteObjectCommand } from '@aws-sdk/client-s3';
import fs from 'fs';
import path from 'path';
import Product from '../models/productModel.js';
import { isAuth, isAdmin } from '../util.js';
import config from '../config.js';

const router = express.Router();

// Configure AWS S3 (only if credentials are available)
const isS3Configured = config.accessKeyId && config.secretAccessKey && config.bucketName;
let s3Client = null;

if (isS3Configured) {
  s3Client = new S3Client({
    credentials: {
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
    },
    region: config.region
  });
  console.log('✅ S3 client configured for product route');
} else {
  console.log('⚠️ S3 not configured. Using local file deletion only.');
}

// Helper function to extract S3 key from URL
const extractS3KeyFromUrl = (imageUrl) => {
  if (!imageUrl) return null;

  // Handle different S3 URL formats
  if (imageUrl.includes('amazonaws.com')) {
    // Format: https://bucket-name.s3.region.amazonaws.com/key
    // or https://s3.region.amazonaws.com/bucket-name/key
    const urlParts = imageUrl.split('/');
    if (imageUrl.includes(`${config.bucketName}.s3`)) {
      // bucket-name.s3.region.amazonaws.com/key
      // The key is everything after the domain
      const key = urlParts.slice(3).join('/');
      console.log(`Extracted S3 key from bucket subdomain URL: ${key}`);
      return key;
    } else if (imageUrl.includes('s3.') && imageUrl.includes(`/${config.bucketName}/`)) {
      // s3.region.amazonaws.com/bucket-name/key
      const bucketIndex = urlParts.indexOf(config.bucketName);
      const key = urlParts.slice(bucketIndex + 1).join('/');
      console.log(`Extracted S3 key from path-style URL: ${key}`);
      return key;
    }
  }

  console.log(`Could not extract S3 key from URL: ${imageUrl}`);
  return null;
};

// Helper function to delete local image file
const deleteLocalImage = async (imageUrl) => {
  if (!imageUrl) return { success: false, message: 'No image URL provided' };

  try {
    // Check if this is a local file (starts with /uploads/)
    if (imageUrl.startsWith('/uploads/')) {
      const filePath = path.join(process.cwd(), imageUrl);
      
      // Check if file exists
      if (fs.existsSync(filePath)) {
        await fs.promises.unlink(filePath);
        console.log(`Successfully deleted local image: ${filePath}`);
        return { success: true, message: 'Local image deleted successfully' };
      } else {
        return { success: false, message: 'Local image file not found' };
      }
    }
    
    return { success: false, message: 'Not a local image URL' };
  } catch (error) {
    console.error('Error deleting local image:', error);
    return { success: false, message: error.message };
  }
};

// Helper function to delete image from S3
const deleteImageFromS3 = async (imageUrl) => {
  if (!imageUrl) return { success: false, message: 'No image URL provided' };
  if (!isS3Configured) return { success: false, message: 'S3 not configured' };

  try {
    const s3Key = extractS3KeyFromUrl(imageUrl);

    if (!s3Key) {
      return { success: false, message: 'Unable to extract S3 key from URL' };
    }

    const command = new DeleteObjectCommand({
      Bucket: config.bucketName,
      Key: s3Key,
    });

    await s3Client.send(command);
    console.log(`Successfully deleted image from S3: ${s3Key}`);
    return { success: true, message: 'Image deleted from S3' };
  } catch (error) {
    console.error('Error deleting image from S3:', error);
    return { success: false, message: error.message };
  }
};

// Unified function to delete image (tries both S3 and local)
const deleteImage = async (imageUrl) => {
  if (!imageUrl) return { success: false, message: 'No image URL provided' };

  // Try S3 first if it's an S3 URL
  if (imageUrl.includes('amazonaws.com') && isS3Configured) {
    const s3Result = await deleteImageFromS3(imageUrl);
    if (s3Result.success) {
      return s3Result;
    }
  }

  // Try local deletion if it's a local URL
  if (imageUrl.startsWith('/uploads/')) {
    return await deleteLocalImage(imageUrl);
  }

  // If it doesn't match any pattern, log and return
  console.log(`Image URL doesn't match any deletion pattern: ${imageUrl}`);
  return { success: false, message: 'Image URL format not recognized for deletion' };
};

router.get('/', async (req, res) => {
  const category = req.query.category ? { category: req.query.category } : {};
  const searchKeyword = req.query.searchKeyword
    ? {
        name: {
          $regex: req.query.searchKeyword,
          $options: 'i',
        },
      }
    : {};
  const sortOrder = req.query.sortOrder
    ? req.query.sortOrder === 'lowest'
      ? { price: 1 }
      : { price: -1 }
    : { _id: -1 };
  const products = await Product.find({ ...category, ...searchKeyword }).sort(
    sortOrder
  );
  res.send(products);
});

router.get('/:id', async (req, res) => {
  try {
    const product = await Product.findOne({ _id: req.params.id });
    if (product) {
      res.send(product);
    } else {
      res.status(404).send({ message: 'Product Not Found.' });
    }
  } catch (error) {
    console.error('Error fetching product:', error);
    res.status(500).send({ message: 'Error fetching product details: ' + error.message });
  }
});
router.post('/:id/reviews', isAuth, async (req, res) => {
  const product = await Product.findById(req.params.id);
  if (product) {
    const review = {
      name: req.body.name,
      rating: Number(req.body.rating),
      comment: req.body.comment,
    };
    product.reviews.push(review);
    product.numReviews = product.reviews.length;
    product.rating =
      product.reviews.reduce((a, c) => c.rating + a, 0) /
      product.reviews.length;
    const updatedProduct = await product.save();
    res.status(201).send({
      data: updatedProduct.reviews[updatedProduct.reviews.length - 1],
      message: 'Review saved successfully.',
    });
  } else {
    res.status(404).send({ message: 'Product Not Found' });
  }
});
router.put('/:id', isAuth, isAdmin, async (req, res) => {
  const productId = req.params.id;
  const product = await Product.findById(productId);
  if (product) {
    // Store old image URL for potential deletion
    const oldImageUrl = product.image;
    const newImageUrl = req.body.image;

    // Update product fields
    product.name = req.body.name;
    product.price = req.body.price;
    product.image = req.body.image;
    product.brand = req.body.brand;
    product.category = req.body.category;
    product.countInStock = req.body.countInStock;
    product.description = req.body.description;

    const updatedProduct = await product.save();

    if (updatedProduct) {
      // Delete old image from storage if image was changed and not a default image
      if (oldImageUrl && newImageUrl && oldImageUrl !== newImageUrl && !oldImageUrl.startsWith('/images/')) {
        const deleteResult = await deleteImage(oldImageUrl);
        console.log('Old image deletion result:', deleteResult);
      }

      return res
        .status(200)
        .send({ message: 'Product Updated', data: updatedProduct });
    }
  }
  return res.status(500).send({ message: ' Error in Updating Product.' });
});

// Updated delete route with unified image deletion (S3 + local)
router.delete('/:id', isAuth, isAdmin, async (req, res) => {
  try {
    // First, find the product to get the image URL
    const productToDelete = await Product.findById(req.params.id);

    if (!productToDelete) {
      return res.status(404).send({ message: 'Product Not Found.' });
    }

    // Store image URL before deletion
    const imageUrl = productToDelete.image;

    // Delete the product from database first
    const deletedProduct = await Product.findByIdAndDelete(req.params.id);

    if (deletedProduct) {
      // Delete associated image from storage (S3 or local)
      if (imageUrl && !imageUrl.startsWith('/images/')) { // Don't delete default images
        const imageDeleteResult = await deleteImage(imageUrl);

        if (imageDeleteResult.success) {
          res.send({
            message: 'Product and associated image deleted successfully',
            imageResult: imageDeleteResult.message,
          });
        } else {
          res.send({
            message: 'Product deleted, but failed to delete image',
            imageError: imageDeleteResult.message,
          });
        }
      } else {
        res.send({ message: 'Product deleted (no custom image to remove)' });
      }
    } else {
      res.status(404).send({ message: 'Product Not Found.' });
    }
  } catch (error) {
    console.error('Error in product deletion:', error);
    res.status(500).send({ message: 'Error in Deletion: ' + error.message });
  }
});
router.post('/', isAuth, isAdmin, async (req, res) => {
  try {
    const product = new Product({
      name: req.body.name,
      price: req.body.price,
      image: req.body.image || '/images/p1.jpg', // Provide default image if none provided
      brand: req.body.brand,
      category: req.body.category,
      countInStock: req.body.countInStock,
      description: req.body.description,
      rating: req.body.rating || 0,
      numReviews: req.body.numReviews || 0,
    });

    const newProduct = await product.save();

    if (newProduct) {
      return res
        .status(201)
        .send({ message: 'New Product Created', data: newProduct });
    }
    return res.status(500).send({ message: ' Error in Creating Product.' });
  } catch (error) {
    console.error('Error creating product:', error);
    return res.status(500).send({ message: 'Error in Creating Product: ' + error.message });
  }
});

// Test endpoint to verify S3 key extraction
router.post('/test-s3-key', isAuth, isAdmin, (req, res) => {
  const imageUrl = req.body.imageUrl;
  const s3Key = extractS3KeyFromUrl(imageUrl);

  res.json({
    imageUrl,
    extractedKey: s3Key,
    bucketName: config.bucketName,
  });
});

export default router;

import express from 'express';
import multer from 'multer';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import config from '../config.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// Configure AWS S3 Client (SDK v3)
const s3Client = new S3Client({
  region: config.region,
  credentials: {
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
  },
});

// Memory storage for S3 uploads (temporary)
const memoryStorage = multer.memoryStorage();
const uploadToMemory = multer({ 
  storage: memoryStorage,
  limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

// S3 upload route
router.post('/s3', uploadToMemory.single('image'), async (req, res) => {
  try {
    console.log('S3 upload attempt started...');
    
    if (!req.file) {
      console.error('No file uploaded to S3');
      return res.status(400).send('No file uploaded');
    }

    const fileName = `products/${Date.now().toString()}-${req.file.originalname}`;
    console.log('Uploading file to S3:', fileName);
    console.log('Bucket:', config.bucketName);
    console.log('Region:', config.region);

    const uploadParams = {
      Bucket: config.bucketName,
      Key: fileName,
      Body: req.file.buffer,
      ContentType: req.file.mimetype,
      ACL: 'public-read'
    };

    const command = new PutObjectCommand(uploadParams);
    const result = await s3Client.send(command);
    
    // Construct the public URL for the uploaded file
    const fileUrl = `https://${config.bucketName}.s3.${config.region}.amazonaws.com/${fileName}`;
    console.log('S3 upload successful:', fileUrl);
    
    res.send({ image: fileUrl });
    
  } catch (error) {
    console.error('S3 upload error:', error);
    res.status(500).send('S3 upload failed: ' + error.message);
  }
});

// Local storage configuration (fallback)
const storage = multer.diskStorage({
  destination(req, file, cb) {
    cb(null, 'uploads/');
  },
  filename(req, file, cb) {
    cb(null, `${Date.now().toString()}-${file.originalname}`);
  },
});

const upload = multer({ storage });

// Local upload route (fallback)
router.post('/', upload.single('image'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).send('No file uploaded');
    }
    res.send({ image: `/${req.file.path}` });
  } catch (error) {
    console.error('Local upload error:', error);
    res.status(500).send('Upload failed: ' + error.message);
  }
});

export default router;
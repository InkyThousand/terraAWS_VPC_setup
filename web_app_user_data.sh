#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
set -x

echo "=== WEB APP USER DATA SCRIPT START ==="
echo "Script started at: $(date)"

# Update and install packages
dnf update -y
dnf install -y httpd php php-json php-gd php-mbstring php-xml php-curl awscli

# Create directories and set permissions
mkdir -p /var/www/html/uploads
chmod 777 /var/www/html/uploads

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create health check page
echo "OK - $(date)" > /var/www/html/health.html

# Create a simple index.php
cat > /var/www/html/index.php << 'EOF'
<?php
// Enable error reporting for debugging
ini_set('display_errors', 1);
error_reporting(E_ALL);

// AWS Region and resource names
$region = '${AWS_REGION}';
$bucketName = '${S3_BUCKET}';
$tableName = '${DYNAMODB_TABLE}';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Analysis App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        form { margin-bottom: 20px; padding: 15px; border: 1px solid #ddd; }
        .images { display: flex; flex-wrap: wrap; }
        .image-card { margin: 10px; padding: 10px; border: 1px solid #ccc; width: 300px; }
        .image-card img { max-width: 100%; max-height: 200px; }
        .label { display: inline-block; margin: 2px; padding: 2px 6px; background: #eee; border-radius: 3px; }
        .face { background: #d4edda; }
        .warning { background: #f8d7da; }
    </style>
</head>
<body>
    <h1>Image Analysis Application</h1>
    
    <form action="upload.php" method="post" enctype="multipart/form-data">
        <h2>Upload an Image for Analysis</h2>
        <input type="file" name="imageFile" accept="image/jpeg,image/png,image/jpg" required>
        <p>Supported formats: JPG, JPEG, PNG</p>
        <button type="submit">Upload & Analyze</button>
    </form>

    <h2>Recent Analyses</h2>
    <div class="images">
        <?php
        // Check if AWS SDK is available
        if (file_exists('vendor/autoload.php')) {
            require 'vendor/autoload.php';
            
            try {
                // Create DynamoDB client
                $dynamoDb = new Aws\DynamoDb\DynamoDbClient([
                    'version' => 'latest',
                    'region'  => $region
                ]);
                
                // Create S3 client
                $s3 = new Aws\S3\S3Client([
                    'version' => 'latest',
                    'region'  => $region
                ]);
                
                // Scan the table for recent items (limited to 10)
                $result = $dynamoDb->scan([
                    'TableName' => $tableName,
                    'Limit' => 10
                ]);
                
                if (isset($result['Items']) && count($result['Items']) > 0) {
                    foreach ($result['Items'] as $item) {
                        $imageId = $item['image_id']['S'];
                        $s3Key = $item['s3_key']['S'];
                        $timestamp = $item['timestamp']['S'];
                        $labels = isset($item['labels']['L']) ? $item['labels']['L'] : [];
                        $hasFaces = isset($item['has_faces']['BOOL']) ? $item['has_faces']['BOOL'] : false;
                        $faceCount = isset($item['face_count']['N']) ? $item['face_count']['N'] : 0;
                        $isInappropriate = isset($item['is_inappropriate']['BOOL']) ? $item['is_inappropriate']['BOOL'] : false;
                        
                        // Generate a pre-signed URL for the image (valid for 1 hour)
                        // Use the correct method with array parameters
                        $cmd = $s3->getCommand('GetObject', [
                            'Bucket' => $bucketName,
                            'Key'    => $s3Key
                        ]);
                        $request = $s3->createPresignedRequest($cmd, '+1 hour');
                        $imageUrl = (string) $request->getUri();
                        
                        echo '<div class="image-card">';
                        echo '<h3>Image: ' . htmlspecialchars($imageId) . '</h3>';
                        echo '<img src="' . htmlspecialchars($imageUrl) . '" alt="Analyzed Image">';
                        echo '<p><strong>Analyzed:</strong> ' . htmlspecialchars(date('Y-m-d H:i:s', strtotime($timestamp))) . '</p>';
                        
                        echo '<p><strong>Labels:</strong> ';
                        if (!empty($labels)) {
                            foreach ($labels as $label) {
                                echo '<span class="label">' . htmlspecialchars($label['S']) . '</span> ';
                            }
                        } else {
                            echo 'No labels detected';
                        }
                        echo '</p>';
                        
                        if ($hasFaces) {
                            echo '<p><span class="label face">Faces detected: ' . htmlspecialchars($faceCount) . '</span></p>';
                        }
                        if ($isInappropriate) {
                            echo '<p><span class="label warning">Content warning</span></p>';
                        }
                        
                        echo '</div>';
                    }
                } else {
                    echo '<p>No images have been analyzed yet. Upload an image to get started!</p>';
                }
                
            } catch (Exception $e) {
                echo '<p>Error: ' . htmlspecialchars($e->getMessage()) . '</p>';
            }
        } else {
            // AWS SDK not available, show local uploads
            echo '<p>AWS SDK not available. Showing local uploads only.</p>';
            
            // Display locally uploaded images
            $uploadDir = 'uploads/';
            if (is_dir($uploadDir)) {
                $files = scandir($uploadDir);
                $imageFiles = array_filter($files, function($file) {
                    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
                    return in_array($ext, ['jpg', 'jpeg', 'png']) && $file != '.' && $file != '..';
                });
                
                if (count($imageFiles) > 0) {
                    foreach ($imageFiles as $file) {
                        $filePath = $uploadDir . $file;
                        $imageId = pathinfo($file, PATHINFO_FILENAME);
                        
                        echo '<div class="image-card">';
                        echo '<h3>Image: ' . htmlspecialchars($imageId) . '</h3>';
                        echo '<img src="' . htmlspecialchars($filePath) . '" alt="Uploaded Image">';
                        echo '<p><strong>Uploaded:</strong> ' . htmlspecialchars(date('Y-m-d H:i:s', filemtime($filePath))) . '</p>';
                        echo '<p>Analysis pending...</p>';
                        echo '</div>';
                    }
                } else {
                    echo '<p>No images have been uploaded yet.</p>';
                }
            } else {
                echo '<p>Upload directory not found.</p>';
            }
        }
        ?>
    </div>
</body>
</html>
EOF

# Create a simple upload.php
cat > /var/www/html/upload.php << 'EOF'
<?php
// This will be implemented in the deployment step
echo "<h1>Upload functionality will be implemented soon</h1>";
echo "<p><a href='index.php'>Back to home</a></p>";
?>
EOF

# Set proper permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

echo "=== WEB APP USER DATA SCRIPT COMPLETED ==="

const AWS = require('aws-sdk');
const rekognition = new AWS.Rekognition();
const s3 = new AWS.S3();
const sns = new AWS.SNS();
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    // Process SNS message
    const message = event.Records[0].Sns.Message;
    const s3Event = JSON.parse(message);
    
    // Get the object details from the event
    const bucket = s3Event.Records[0].s3.bucket.name;
    const key = decodeURIComponent(s3Event.Records[0].s3.object.key.replace(/\+/g, ' '));
    const imageId = key.split('/').pop().split('.')[0]; // Extract image ID from key
    
    console.log(`Processing image: ${bucket}/${key} (ID: ${imageId})`);
    
    try {
        // Perform image analysis with Rekognition
        const results = await analyzeImage(bucket, key);
        
        // Update the S3 object metadata with the analysis results
        await updateMetadata(bucket, key, results);
        
        // Store results in DynamoDB
        await storeResultsInDynamoDB(imageId, bucket, key, results);
        
        // Publish results to SNS
        await publishResults(bucket, key, imageId, results);
        
        console.log('Image processing completed successfully');
        return {
            statusCode: 200,
            body: JSON.stringify({ 
                message: 'Image processed successfully', 
                imageId: imageId,
                results 
            }),
        };
    } catch (error) {
        console.error('Error processing image:', error);
        throw error;
    }
};

async function analyzeImage(bucket, key) {
    console.log('Analyzing image with Rekognition');
    
    // Get the image from S3
    const params = {
        Image: {
            S3Object: {
                Bucket: bucket,
                Name: key
            }
        }
    };
    
    // Perform multiple analyses in parallel
    const [labelResults, moderationResults, faceResults] = await Promise.all([
        // Detect labels (objects, scenes, concepts)
        rekognition.detectLabels({
            ...params,
            MaxLabels: 10,
            MinConfidence: 70
        }).promise(),
        
        // Check for inappropriate content
        rekognition.detectModerationLabels({
            ...params,
            MinConfidence: 60
        }).promise(),
        
        // Detect faces
        rekognition.detectFaces({
            ...params,
            Attributes: ['ALL']
        }).promise()
    ]);
    
    return {
        labels: labelResults.Labels,
        moderationLabels: moderationResults.ModerationLabels,
        faces: faceResults.FaceDetails,
        hasFaces: faceResults.FaceDetails.length > 0,
        isInappropriate: moderationResults.ModerationLabels.length > 0,
        dominantLabels: labelResults.Labels.slice(0, 5).map(label => label.Name),
        timestamp: new Date().toISOString()
    };
}

async function updateMetadata(bucket, key, results) {
    console.log('Updating S3 object metadata');
    
    // Get the current object metadata
    const headParams = {
        Bucket: bucket,
        Key: key
    };
    
    const objectData = await s3.headObject(headParams).promise();
    const metadata = objectData.Metadata || {};
    
    // Prepare new metadata
    const newMetadata = {
        ...metadata,
        'x-amz-meta-labels': results.dominantLabels.join(','),
        'x-amz-meta-has-faces': String(results.hasFaces),
        'x-amz-meta-is-inappropriate': String(results.isInappropriate),
        'x-amz-meta-face-count': String(results.faces.length),
        'x-amz-meta-processed': 'true',
        'x-amz-meta-processed-date': results.timestamp
    };
    
    // Copy the object to itself with new metadata
    const copyParams = {
        Bucket: bucket,
        CopySource: `${bucket}/${key}`,
        Key: key,
        MetadataDirective: 'REPLACE',
        Metadata: newMetadata
    };
    
    await s3.copyObject(copyParams).promise();
}

async function storeResultsInDynamoDB(imageId, bucket, key, results) {
    console.log(`Storing analysis results in DynamoDB for image ${imageId}`);
    
    const item = {
        image_id: imageId,
        s3_bucket: bucket,
        s3_key: key,
        timestamp: results.timestamp,
        labels: results.dominantLabels,
        has_faces: results.hasFaces,
        face_count: results.faces.length,
        is_inappropriate: results.isInappropriate,
        analysis_details: {
            labels: results.labels,
            faces: results.faces,
            moderationLabels: results.moderationLabels
        }
    };
    
    const params = {
        TableName: process.env.DYNAMODB_TABLE,
        Item: item
    };
    
    await dynamodb.put(params).promise();
    console.log(`Results stored in DynamoDB for image ${imageId}`);
}

async function publishResults(bucket, key, imageId, results) {
    console.log('Publishing results to SNS');
    
    const params = {
        Message: JSON.stringify({
            bucket,
            key,
            imageId,
            results: {
                dominantLabels: results.dominantLabels,
                hasFaces: results.hasFaces,
                faceCount: results.faces.length,
                isInappropriate: results.isInappropriate,
                moderationLabels: results.moderationLabels.map(label => label.Name),
                timestamp: results.timestamp
            }
        }),
        Subject: `Image Analysis Results: ${imageId}`,
        TopicArn: process.env.SNS_TOPIC_ARN
    };
    
    await sns.publish(params).promise();
}

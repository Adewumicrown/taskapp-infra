#!/bin/bash
# Completely empties an S3 bucket including all versions and delete markers
BUCKET=$1
PROFILE=${2:-Taskapp-cluster-ops}
REGION=${3:-us-east-1}

echo "Emptying bucket: $BUCKET"

# Delete all object versions
VERSIONS=$(aws s3api list-object-versions \
  --region $REGION \
  --profile $PROFILE \
  --bucket $BUCKET \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
  --output json 2>/dev/null)

if [ "$VERSIONS" != "null" ] && [ ! -z "$VERSIONS" ] && [ "$VERSIONS" != '{"Objects": null}' ]; then
  echo "Deleting object versions..."
  aws s3api delete-objects \
    --region $REGION \
    --profile $PROFILE \
    --bucket $BUCKET \
    --delete "$VERSIONS" > /dev/null
fi

# Delete all delete markers
MARKERS=$(aws s3api list-object-versions \
  --region $REGION \
  --profile $PROFILE \
  --bucket $BUCKET \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
  --output json 2>/dev/null)

if [ "$MARKERS" != "null" ] && [ ! -z "$MARKERS" ] && [ "$MARKERS" != '{"Objects": null}' ]; then
  echo "Deleting delete markers..."
  aws s3api delete-objects \
    --region $REGION \
    --profile $PROFILE \
    --bucket $BUCKET \
    --delete "$MARKERS" > /dev/null
fi

echo "Bucket $BUCKET is now empty!"

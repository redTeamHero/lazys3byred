# lazys3byred


## Overview

This Ruby script is designed to scan for AWS S3 buckets, validate their existence, and perform AWS CLI operations on them. It utilizes multithreading for efficient scanning, rate limiting to avoid overloading, and supports various configurations through command-line options.

### Key Features

- **Bucket Existence Check**: Validates whether an S3 bucket exists using both HTTP requests and AWS SDK.
- **AWS CLI Operations**: Executes AWS CLI commands (`copy`, `delete`, `move`, `list`) on identified buckets.
- **Multithreading**: Uses multiple threads to speed up the scanning process.
- **Rate Limiting**: Includes a rate limit to control the frequency of requests.
- **Flexible Configuration**: Configurable through command-line options.

## Installation

Ensure you have Ruby installed and the necessary gems (`aws-sdk-s3`, `net-http`, `open3`, `logger`, `json`, `thread`, `timeout`) by running:

```bash
gem install aws-sdk-s3 net-http open3 logger json
```

## Usage

### Command-Line Options

- `-f`, `--file FILE`: Specifies a file containing common bucket prefixes (one per line).
- `-c`, `--codes x,y,z`: Comma-separated list of HTTP status codes to display (e.g., `200,403`).
- `-o`, `--output FILE`: Output file to save results (optional).
- `-s`, `--timeout SECONDS`: Timeout for HTTP requests (default: 5 seconds).
- `-T`, `--threads COUNT`: Number of threads to use for scanning (default: 10).
- `-r`, `--rate LIMIT`: Rate limit in seconds between requests (default: 1 second).
- `-a`, `--actions x,y,z`: AWS CLI actions to perform. Available actions are `copy`, `delete`, `move`, and `ls`.

### Examples

#### Basic Usage

Scan for buckets listed in `buckets.txt` and display only buckets returning HTTP status code `200`:

```bash
ruby scanner.rb -f buckets.txt -c 200
```

#### Scan and Perform AWS CLI Actions

Scan for buckets and perform a combination of AWS CLI actions (`copy`, `delete`, and `list`) on each found bucket:

```bash
ruby scanner.rb -f buckets.txt -a copy,delete,ls
```

#### Custom Timeout and Thread Count

Set a custom timeout of `10` seconds and use `5` threads for scanning:

```bash
ruby scanner.rb -f buckets.txt -s 10 -T 5
```

#### Save Results to a File

Scan for buckets and save the results to `results.txt`:

```bash
ruby scanner.rb -f buckets.txt -o results.txt
```

#### Rate Limiting

Apply a rate limit of `2` seconds between requests:

```bash
ruby scanner.rb -f buckets.txt -r 2
```
Here are some advanced use cases and scenarios.

### 1. **Automated Backup and Archiving**

- **Scenario**: You want to automatically back up your S3 buckets periodically and archive them to another S3 bucket.
- **Implementation**:
  1. Schedule the script using a cron job or an equivalent scheduler.
  2. Use the `copy` action to duplicate data to a backup bucket.
  3. Optionally, use `ls` to list the contents of the backup bucket and verify the backup.

  **Example Command**:
  ```bash
  ruby scanner.rb -f bucket-prefixes.txt -a copy -o backup-results.txt
  ```

### 2. **Data Migration**

- **Scenario**: Migrating data from one S3 bucket to another and ensuring the source bucket is cleaned up afterward.
- **Implementation**:
  1. Use `move` to migrate data and delete it from the source bucket.
  2. Monitor the migration process and log any issues.

  **Example Command**:
  ```bash
  ruby scanner.rb -f bucket-prefixes.txt -a move -o migration-results.txt
  ```

### 3. **Cost Management**

- **Scenario**: You want to regularly audit your S3 buckets to manage costs by deleting unnecessary files or buckets.
- **Implementation**:
  1. Use `delete` to remove old or unused buckets.
  2. List the remaining objects to verify which files are still in use.

  **Example Command**:
  ```bash
  ruby scanner.rb -f bucket-prefixes.txt -a delete -o deletion-results.txt
  ```

### 4. **Content Verification**

- **Scenario**: You want to ensure the content of your S3 buckets is correctly replicated by comparing source and destination buckets.
- **Implementation**:
  1. Use `copy` to replicate content.
  2. Use `ls` to list and compare files in both source and destination buckets.
  3. Implement additional logic to compare file sizes or checksums.

  **Example Command**:
  ```bash
  ruby scanner.rb -f bucket-prefixes.txt -a copy,ls -o verification-results.txt
  ```

### 5. **Rate-Limited Bulk Operations**

- **Scenario**: Performing bulk operations with rate limiting to avoid throttling or excessive charges.
- **Implementation**:
  1. Set a rate limit to control the frequency of AWS CLI commands.
  2. Use `move` or `copy` with a defined rate limit to ensure operations are performed within acceptable limits.

  **Example Command**:
  ```bash
  ruby scanner.rb -f bucket-prefixes.txt -a move -r 5 -o bulk-move-results.txt
  ```

### 6. **Logging and Error Handling Enhancements**

- **Scenario**: You want to improve logging and error handling to capture detailed information about operations.
- **Implementation**:
  1. Enhance the `execute_aws_command` method to capture more detailed logs.
  2. Implement retry logic for transient errors.
  3. Use advanced logging libraries or integrate with monitoring tools.

  **Updated `execute_aws_command` Method**:
  ```ruby
  def execute_aws_command(command)
    stdout, stderr, status = Open3.capture3(command)
    if status.success?
      $logger.info("AWS CLI command successful: #{command}")
      $logger.info(stdout) unless stdout.empty?
    else
      $logger.error("AWS CLI command failed: #{command}")
      $logger.error(stderr) unless stderr.empty?
      # Optional: Implement retry logic here
    end
  end
  ```

### 7. **Dynamic Action Configuration**

- **Scenario**: You need to dynamically configure and chain multiple AWS CLI actions based on specific conditions.
- **Implementation**:
  1. Parse and process complex action configurations from a file or environment variables.
  2. Use a more advanced configuration setup to control the sequence and logic of actions.

  **Example Configuration File (`actions.json`)**:
  ```json
  {
    "buckets": ["bucket1", "bucket2"],
    "actions": [
      {"action": "copy", "destination": "bucket1-copy"},
      {"action": "move", "destination": "bucket2-moved"},
      {"action": "delete"}
    ]
  }
  ```

  **Example Command**:
  ```bash
  ruby scanner.rb -f actions.json -a dynamic
  ```

### 8. **Integration with CI/CD Pipelines**

- **Scenario**: You want to integrate this script into a CI/CD pipeline to automate deployment or migration tasks.
- **Implementation**:
  1. Set up the script as a step in your CI/CD pipeline configuration.
  2. Use environment variables or pipeline parameters to control script execution.

  **Example CI/CD Configuration**:
  ```yaml
  steps:
    - name: Run S3 Operations
      run: ruby scanner.rb -f bucket-prefixes.txt -a move -o ci-cd-results.txt
  ```

### 9. **Handling Large Datasets**

- **Scenario**: You are dealing with a large number of S3 buckets and need to optimize performance.
- **Implementation**:
  1. Implement asynchronous processing or batching.
  2. Optimize memory usage and manage concurrency to handle large datasets efficiently.

  **Example Command**:
  ```bash
  ruby scanner.rb -f large-bucket-prefixes.txt -T 20 -a move -o large-dataset-results.txt
  ```

These advanced use cases and enhancements can help make the script more versatile, efficient, and suitable for various complex scenarios.

## Notes

- Ensure AWS CLI is installed and configured with appropriate credentials.
- The script will log errors and outputs to standard output. Results are also logged and can be saved to a file if specified.
- Be cautious with actions like `delete` and `move`, as they can affect data in S3.

# Authors
- http://twitter.com/nahamsec
- http://twitter.com/JobertAbma
Coded by red
# Changelog 

1.0 - Release

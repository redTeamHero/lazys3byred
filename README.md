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

### How It Works

1. **Initialization**: The script initializes logging, defines utility methods, and sets up classes for handling S3 buckets and scanning.
2. **S3 Class**: Manages S3 bucket operations, including existence checks and executing AWS CLI commands.
3. **Scanner Class**: Handles the scanning process with multithreading, rate limiting, and performs AWS CLI actions on found buckets.
4. **Wordlist Class**: Generates permutations of bucket names based on various patterns.
5. **Command-Line Parsing**: Configures the script according to user input.
6. **Execution**: Reads the wordlist from a file, performs scanning, and handles results. Optionally, saves results to a file.

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

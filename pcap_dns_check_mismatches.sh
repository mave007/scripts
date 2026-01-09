#!/bin/bash

# DNS Query/Response Matching Script
# This script analyzes DNS traffic in PCAP files to verify that every query has a matching response
# Matching is done by DNS transaction ID and IP/port combinations
# Supports both single-file and batch processing modes

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
ITALIC_GREEN='\033[3;32m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 <pcap_file> [options]"
    echo "   or: $0 -f <pcap_files...> [options]"
    echo ""
    echo "Single File Mode:"
    echo "  Analyze a single PCAP file"
    echo ""
    echo "Batch Mode:"
    echo "  -f <files>                 Specify one or more PCAP files (supports globbing)"
    echo "                             If -f not specified, scans current directory for .pcap files"
    echo ""
    echo "Options:"
    echo "  -t, --timeout <seconds>    Maximum time between query and response (default: 5)"
    echo "  -v, --verbose              Show detailed output"
    echo "  -vvv                       Very verbose - show tshark commands and detailed output"
    echo "  -q, --quiet                Quiet mode - only show brief summary (exit 0=success, 128=failure)"
    echo "  -l, --local-time           Display timestamps in local timezone (default: UTC)"
    echo "  -T, --timestamp <epoch>    Filter packets around a specific timestamp (epoch format)"
    echo "                             Also accepts: '2026-01-09 14:30:00' or '2026-01-09T14:30:00'"
    echo "  -s, --span <seconds>       Time span before/after timestamp to include (default: 2)"
    echo "  -o, --output <file>        Save unmatched queries to PCAP file (single mode)"
    echo "                             In batch mode, creates files in dns_analysis_results/"
    echo "  -h, --help                 Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dns_traffic.pcap -t 10 -v"
    echo "  $0 dns_traffic.pcap -T 1704812400 -s 5"
    echo "  $0 -f dns*.pcap -v"
    echo "  $0 -f file1.pcap file2.pcap -T '2026-01-09 14:57:00 UTC'"
    exit 1
}

# Default values
TIMEOUT=5
VERBOSE=0
VERY_VERBOSE=0
QUIET=0
LOCAL_TIME=0
TARGET_TIMESTAMP=""
TIME_SPAN=2
OUTPUT_FILE=""
BATCH_MODE=0
USER_FILES=()
PCAP_FILE=""

# Parse command line arguments
if [ $# -eq 0 ]; then
    usage
fi

# Check if first argument is -f (batch mode) or a file (single mode)
if [[ "$1" == "-f" ]]; then
    BATCH_MODE=1
    shift
    # Collect file arguments
    while [ $# -gt 0 ] && [[ "$1" != -* ]]; do
        USER_FILES+=("$1")
        shift
    done
else
    # Single file mode - first arg should be the pcap file
    if [[ "$1" != -* ]]; then
        PCAP_FILE="$1"
        shift
    fi
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--timeout)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo -e "${RED}Error: -t/--timeout requires a numeric argument${NC}"
                exit 1
            fi
            # Validate that timeout is a number
            if ! [[ "$2" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                echo -e "${RED}Error: timeout must be a valid number (got: '$2')${NC}"
                exit 1
            fi
            TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -vvv)
            VERY_VERBOSE=1
            VERBOSE=1
            shift
            ;;
        -q|--quiet)
            QUIET=1
            shift
            ;;
        -l|--local-time)
            LOCAL_TIME=1
            shift
            ;;
        -T|--timestamp)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo -e "${RED}Error: -T/--timestamp requires a timestamp argument${NC}"
                exit 1
            fi
            # Check if timestamp is already in epoch format (integer or float)
            if [[ "$2" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                TARGET_TIMESTAMP="$2"
            else
                # Try to convert timestamp to epoch format
                # Try macOS date command first (date -j -f)
                CONVERTED_TIMESTAMP=$(date -j -f "%Y-%m-%d %H:%M:%S" "$2" "+%s" 2>/dev/null || \
                                     date -j -f "%Y-%m-%dT%H:%M:%S" "$2" "+%s" 2>/dev/null || \
                                     date -j -f "%Y-%m-%d %H:%M:%S %Z" "$2" "+%s" 2>/dev/null || \
                                     date -d "$2" "+%s" 2>/dev/null)
                
                if [ -z "$CONVERTED_TIMESTAMP" ]; then
                    echo -e "${RED}Error: Unable to parse timestamp '$2'${NC}"
                    echo "Supported formats:"
                    echo "  - Epoch: 1704812400"
                    echo "  - ISO 8601: 2026-01-09 14:30:00 or 2026-01-09T14:30:00"
                    echo "  - With timezone: 2026-01-09 14:30:00 UTC"
                    exit 1
                fi
                TARGET_TIMESTAMP="$CONVERTED_TIMESTAMP"
            fi
            shift 2
            ;;
        -s|--span)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo -e "${RED}Error: -s/--span requires a numeric argument${NC}"
                exit 1
            fi
            # Validate that span is a number
            if ! [[ "$2" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                echo -e "${RED}Error: span must be a valid number (got: '$2')${NC}"
                exit 1
            fi
            TIME_SPAN="$2"
            shift 2
            ;;
        -o|--output)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo -e "${RED}Error: -o/--output requires a filename argument${NC}"
                exit 1
            fi
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}"
            usage
            ;;
    esac
done

# Validate batch mode vs single mode
if [ "$BATCH_MODE" -eq 0 ] && [ -z "$PCAP_FILE" ]; then
    echo -e "${RED}Error: No PCAP file specified${NC}"
    usage
fi

# Check if tshark is available
if ! command -v tshark &> /dev/null; then
    echo -e "${RED}Error: tshark is not installed${NC}"
    echo "Install it with: brew install wireshark (on macOS) or apt-get install tshark (on Linux)"
    exit 1
fi

# Check if editcap is available (needed for -o flag)
if [ -n "$OUTPUT_FILE" ] && ! command -v editcap &> /dev/null; then
    echo -e "${RED}Error: editcap is not installed (required for -o flag)${NC}"
    echo "Install it with: brew install wireshark (on macOS) or apt-get install tshark (on Linux)"
    exit 1
fi

# Function to process a single PCAP file
process_pcap_file() {
    local PCAP_FILE="$1"
    local OUTPUT_FILE="$2"
    
    # Check if pcap file exists
    if [ ! -f "$PCAP_FILE" ]; then
        echo -e "${RED}Error: PCAP file '$PCAP_FILE' not found${NC}"
        return 1
    fi

# Print headers unless in quiet mode
if [ "$QUIET" -eq 0 ]; then
    echo -e "${GREEN}=== DNS Query/Response Analysis ===${NC}"
    echo "PCAP File: $PCAP_FILE"
    echo "Response Timeout: ${TIMEOUT}s"
    if [ -n "$TARGET_TIMESTAMP" ]; then
        echo "Time Filter: ${TARGET_TIMESTAMP} ±${TIME_SPAN}s"
    fi
    echo ""
fi

# Build time filter if timestamp is specified
TIME_FILTER=""
if [ -n "$TARGET_TIMESTAMP" ]; then
    START_TIME=$(echo "$TARGET_TIMESTAMP - $TIME_SPAN" | bc)
    END_TIME=$(echo "$TARGET_TIMESTAMP + $TIME_SPAN" | bc)
    TIME_FILTER=" && frame.time_epoch >= $START_TIME && frame.time_epoch <= $END_TIME"
fi

# Create temporary files for queries and responses
QUERIES_FILE=$(mktemp)
RESPONSES_FILE=$(mktemp)
UNMATCHED_QUERIES_FILE=$(mktemp)
UNMATCHED_RESPONSES_FILE=$(mktemp)
UNMATCHED_FRAMES_FILE=$(mktemp)
MATCHED_RESPONSES_FILE=$(mktemp)

# Cleanup function
cleanup() {
    rm -f "$QUERIES_FILE" "$RESPONSES_FILE" "$UNMATCHED_QUERIES_FILE" "$UNMATCHED_RESPONSES_FILE" "$MATCHED_RESPONSES_FILE" "$UNMATCHED_FRAMES_FILE"
}
trap cleanup EXIT

[ "$QUIET" -eq 0 ] && echo "Extracting DNS queries..."
# Extract DNS queries (dns.flags.response == 0)
# Format: frame_number|timestamp|src_ip|src_port|dst_ip|dst_port|dns_id|query_name|query_type

QUERY_CMD="tshark -r \"$PCAP_FILE\" -Y \"dns.flags.response == 0${TIME_FILTER}\" -T fields -e frame.number -e frame.time_epoch -e ip.src -e udp.srcport -e ip.dst -e udp.dstport -e dns.id -e dns.qry.name -e dns.qry.type -E separator='|' -E occurrence=f"
[ "$VERY_VERBOSE" -eq 1 ] && echo -e "# ${ITALIC_GREEN}${QUERY_CMD}${NC}"

tshark -r "$PCAP_FILE" -Y "dns.flags.response == 0${TIME_FILTER}" \
    -T fields \
    -e frame.number \
    -e frame.time_epoch \
    -e ip.src \
    -e udp.srcport \
    -e ip.dst \
    -e udp.dstport \
    -e dns.id \
    -e dns.qry.name \
    -e dns.qry.type \
    -E separator='|' \
    -E occurrence=f \
    > "$QUERIES_FILE" 2>/dev/null || true

QUERY_COUNT=$(wc -l < "$QUERIES_FILE" | tr -d ' ')
[ "$QUIET" -eq 0 ] && echo "Found $QUERY_COUNT DNS queries"

[ "$QUIET" -eq 0 ] && echo "Extracting DNS responses..."
# Extract DNS responses (dns.flags.response == 1)
# Format: frame_number|timestamp|src_ip|src_port|dst_ip|dst_port|dns_id|query_name|query_type|rcode

RESPONSE_CMD="tshark -r \"$PCAP_FILE\" -Y \"dns.flags.response == 1${TIME_FILTER}\" -T fields -e frame.number -e frame.time_epoch -e ip.src -e udp.srcport -e ip.dst -e udp.dstport -e dns.id -e dns.qry.name -e dns.qry.type -e dns.flags.rcode -E separator='|' -E occurrence=f"
[ "$VERY_VERBOSE" -eq 1 ] && echo -e "# ${ITALIC_GREEN}${RESPONSE_CMD}${NC}"

tshark -r "$PCAP_FILE" -Y "dns.flags.response == 1${TIME_FILTER}" \
    -T fields \
    -e frame.number \
    -e frame.time_epoch \
    -e ip.src \
    -e udp.srcport \
    -e ip.dst \
    -e udp.dstport \
    -e dns.id \
    -e dns.qry.name \
    -e dns.qry.type \
    -e dns.flags.rcode \
    -E separator='|' \
    -E occurrence=f \
    > "$RESPONSES_FILE" 2>/dev/null || true

RESPONSE_COUNT=$(wc -l < "$RESPONSES_FILE" | tr -d ' ')
[ "$QUIET" -eq 0 ] && echo "Found $RESPONSE_COUNT DNS responses"
[ "$QUIET" -eq 0 ] && echo ""

# Process queries and find matching responses
if [ "$QUIET" -eq 0 ]; then
    echo "Matching queries with responses..."
    echo ""
fi

MATCHED=0
UNMATCHED_QUERIES=0
UNMATCHED_RESPONSES=0
TIMEOUT_EXCEEDED=0

while IFS='|' read -r q_frame q_time q_src_ip q_src_port q_dst_ip q_dst_port q_dns_id q_query_name q_query_type; do
    # Skip empty lines
    [ -z "$q_frame" ] && continue
    
    FOUND_MATCH=0
    
    # Look for matching response
    # Response must have: same DNS ID, query name, query type, and IP/port combination
    while IFS='|' read -r r_frame r_time r_src_ip r_src_port r_dst_ip r_dst_port r_dns_id r_query_name r_query_type r_rcode; do
        # Skip empty lines
        [ -z "$r_frame" ] && continue
        
        # Check if DNS IDs match
        if [ "$q_dns_id" = "$r_dns_id" ]; then
            # Check if query name and query type match (case-sensitive)
            if [ "$q_query_name" = "$r_query_name" ] && \
               [ "$q_query_type" = "$r_query_type" ]; then
                # Check if IP/port combination matches (response reverses the direction)
                if [ "$q_src_ip" = "$r_dst_ip" ] && \
                   [ "$q_src_port" = "$r_dst_port" ] && \
                   [ "$q_dst_ip" = "$r_src_ip" ] && \
                   [ "$q_dst_port" = "$r_src_port" ]; then
                
                # Check response time
                TIME_DIFF=$(echo "$r_time - $q_time" | bc)
                
                    if [ "$VERBOSE" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
                        echo -e "${GREEN}✓${NC} Query frame $q_frame matched with response frame $r_frame"
                        echo "  DNS ID: $q_dns_id | Query: $q_query_name | Type: $q_query_type | Response time: ${TIME_DIFF}s | RCODE: $r_rcode"
                    fi
                    
                    FOUND_MATCH=1
                    MATCHED=$((MATCHED + 1))
                    
                    # Mark this response as matched
                    echo "$r_frame" >> "$MATCHED_RESPONSES_FILE"
                    
                    # Check if response exceeded timeout
                    TIMEOUT_CHECK=$(echo "$TIME_DIFF > $TIMEOUT" | bc)
                    if [ "$TIMEOUT_CHECK" -eq 1 ]; then
                        TIMEOUT_EXCEEDED=$((TIMEOUT_EXCEEDED + 1))
                        [ "$QUIET" -eq 0 ] && echo -e "${YELLOW}⚠${NC} Response for frame $q_frame exceeded timeout (${TIME_DIFF}s > ${TIMEOUT}s)"
                    fi
                    
                    break
                fi
            fi
        fi
    done < "$RESPONSES_FILE"
    
    # If no match found, record it
    if [ "$FOUND_MATCH" -eq 0 ]; then
        UNMATCHED_QUERIES=$((UNMATCHED_QUERIES + 1))
        
        if [ "$QUIET" -eq 0 ]; then
            echo -e "${RED}✗ MISSING RESPONSE${NC} - Query frame $q_frame has no matching response"
        fi
        
        # Save frame number for PCAP extraction
        echo "$q_frame" >> "$UNMATCHED_FRAMES_FILE"
        
        if [ "$VERBOSE" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
            # Convert epoch timestamp to human-readable date
            if [ "$LOCAL_TIME" -eq 1 ]; then
                q_date=$(date -r "${q_time%.*}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || date -d "@${q_time%.*}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null)
            else
                q_date=$(TZ=UTC date -r "${q_time%.*}" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null || TZ=UTC date -d "@${q_time%.*}" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null)
            fi
            echo "  Query Name:   $q_query_name"
            echo "  Query Type:   $q_query_type"
            echo "  Date/Time:    $q_date"
            echo "  DNS ID:       $q_dns_id"
            echo "  Source IP:    ${q_src_ip}:${q_src_port}"
            echo "  Dest IP:      ${q_dst_ip}:${q_dst_port}"
        elif [ "$QUIET" -eq 0 ]; then
            echo "  DNS ID: $q_dns_id | Query: $q_query_name | Type: $q_query_type | Src: ${q_src_ip}:${q_src_port} → Dst: ${q_dst_ip}:${q_dst_port}"
        fi
        
        echo "$q_frame|$q_time|$q_src_ip|$q_src_port|$q_dst_ip|$q_dst_port|$q_dns_id|$q_query_name|$q_query_type" >> "$UNMATCHED_QUERIES_FILE"
    fi
    
done < "$QUERIES_FILE"

# Now check for responses without matching queries
if [ "$QUIET" -eq 0 ]; then
    echo ""
    echo "Checking for responses without matching queries..."
    echo ""
fi

while IFS='|' read -r r_frame r_time r_src_ip r_src_port r_dst_ip r_dst_port r_dns_id r_query_name r_query_type r_rcode; do
    # Skip empty lines
    [ -z "$r_frame" ] && continue
    
    # Skip if this response was already matched
    if grep -q "^${r_frame}$" "$MATCHED_RESPONSES_FILE" 2>/dev/null; then
        continue
    fi
    
    UNMATCHED_RESPONSES=$((UNMATCHED_RESPONSES + 1))
    
    if [ "$QUIET" -eq 0 ]; then
        echo -e "${RED}✗ MISSING QUERY${NC} - Response frame $r_frame has no matching query"
    fi
    
    # Save frame number for PCAP extraction
    echo "$r_frame" >> "$UNMATCHED_FRAMES_FILE"
    
    if [ "$VERBOSE" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
        # Convert epoch timestamp to human-readable date
        if [ "$LOCAL_TIME" -eq 1 ]; then
            r_date=$(date -r "${r_time%.*}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || date -d "@${r_time%.*}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null)
        else
            r_date=$(TZ=UTC date -r "${r_time%.*}" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null || TZ=UTC date -d "@${r_time%.*}" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null)
        fi
        echo "  Query Name:   $r_query_name"
        echo "  Query Type:   $r_query_type"
        echo "  Date/Time:    $r_date"
        echo "  DNS ID:       $r_dns_id"
        echo "  RCODE:        $r_rcode"
        echo "  Source IP:    ${r_src_ip}:${r_src_port}"
        echo "  Dest IP:      ${r_dst_ip}:${r_dst_port}"
    elif [ "$QUIET" -eq 0 ]; then
        echo "  DNS ID: $r_dns_id | Query: $r_query_name | Type: $r_query_type | RCODE: $r_rcode | Src: ${r_src_ip}:${r_src_port} → Dst: ${r_dst_ip}:${r_dst_port}"
    fi
    
    echo "$r_frame|$r_time|$r_src_ip|$r_src_port|$r_dst_ip|$r_dst_port|$r_dns_id|$r_query_name|$r_query_type|$r_rcode" >> "$UNMATCHED_RESPONSES_FILE"
    
done < "$RESPONSES_FILE"

TOTAL_UNMATCHED=$((UNMATCHED_QUERIES + UNMATCHED_RESPONSES))

# Display summary based on mode
if [ "$QUIET" -eq 1 ]; then
    # Quiet mode: single line summary
    if [ "$TOTAL_UNMATCHED" -gt 0 ]; then
        echo "$(basename "$PCAP_FILE"): FAILED - Missing responses: $UNMATCHED_QUERIES, Missing queries: $UNMATCHED_RESPONSES"
    else
        echo "$(basename "$PCAP_FILE"): OK"
    fi
else
    # Normal mode: full summary
    echo ""
    echo -e "${GREEN}=== Summary ===${NC}"
    echo -e "Total Queries:        $QUERY_COUNT"
    echo -e "Total Responses:      $RESPONSE_COUNT"
    echo -e "Matched Pairs:        ${GREEN}${MATCHED}${NC}"
    echo -e "Missing Responses:    ${RED}${UNMATCHED_QUERIES}${NC}"
    echo -e "Missing Queries:      ${RED}${UNMATCHED_RESPONSES}${NC}"

    if [ "$TIMEOUT_EXCEEDED" -gt 0 ]; then
        echo -e "Timeout Exceeded:     ${YELLOW}${TIMEOUT_EXCEEDED}${NC}"
    fi

    # Calculate match percentage
    if [ "$QUERY_COUNT" -gt 0 ]; then
        MATCH_PERCENT=$(echo "scale=2; $MATCHED * 100 / $QUERY_COUNT" | bc)
        echo -e "Match Rate:           ${MATCH_PERCENT}%"
    fi
fi

# Create PCAP file with unmatched packets if requested
if [ -n "$OUTPUT_FILE" ] && [ -s "$UNMATCHED_FRAMES_FILE" ]; then
    if [ "$QUIET" -eq 0 ]; then
        echo ""
        echo "Creating PCAP file with unmatched packets..."
    fi
    
    # Build editcap frame selection argument
    FRAME_SELECTION=$(tr '\n' ',' < "$UNMATCHED_FRAMES_FILE" | sed 's/,$//')
    
    # Use editcap to extract only the unmatched frames
    if editcap -r "$PCAP_FILE" "$OUTPUT_FILE" "$FRAME_SELECTION" 2>/dev/null; then
        UNMATCHED_COUNT=$(wc -l < "$UNMATCHED_FRAMES_FILE" | tr -d ' ')
        [ "$QUIET" -eq 0 ] && echo -e "${GREEN}Successfully created PCAP file with $UNMATCHED_COUNT unmatched packet(s): $OUTPUT_FILE${NC}"
    else
        [ "$QUIET" -eq 0 ] && echo -e "${RED}Error: Failed to create PCAP file${NC}"
    fi
elif [ -n "$OUTPUT_FILE" ] && [ "$QUIET" -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}No unmatched packets found - PCAP file not created${NC}"
fi

# Return with error code if there are unmatched packets
if [ "$TOTAL_UNMATCHED" -gt 0 ]; then
    [ "$QUIET" -eq 0 ] && echo ""
    [ "$QUIET" -eq 0 ] && echo -e "${RED}WARNING: Found mismatches - ${UNMATCHED_QUERIES} missing response(s), ${UNMATCHED_RESPONSES} missing query(ies)${NC}"
    return 128
else
    [ "$QUIET" -eq 0 ] && echo ""
    [ "$QUIET" -eq 0 ] && echo -e "${GREEN}SUCCESS: All DNS queries have matching responses${NC}"
    return 0
fi
}

# Main execution logic
if [ "$BATCH_MODE" -eq 1 ]; then
    # Batch mode processing
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    echo -e "${BLUE}=== Batch DNS Analysis ===${NC}"
    echo "Directory: $SCRIPT_DIR"
    echo ""
    
    # Determine which files to process
    if [ ${#USER_FILES[@]} -gt 0 ]; then
        # User specified files with -f
        echo "Processing specified files..."
        PCAP_FILES=""
        for file_pattern in "${USER_FILES[@]}"; do
            for file in $file_pattern; do
                if [ -f "$file" ]; then
                    abs_path=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
                    PCAP_FILES="${PCAP_FILES}${abs_path}"$'\n'
                else
                    echo -e "${YELLOW}Warning: File not found: $file${NC}"
                fi
            done
        done
        PCAP_FILES=$(echo "$PCAP_FILES" | sed '/^$/d' | sort)
    else
        # Find all .pcap files (excluding .part files unless explicitly specified)
        echo "Searching for PCAP files in directory..."
        PCAP_FILES=$(find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.pcap" ! -name "*.part" | sort)
    fi
    
    if [ -z "$PCAP_FILES" ]; then
        echo -e "${YELLOW}No PCAP files found${NC}"
        exit 0
    fi
    
    TOTAL_FILES=$(echo "$PCAP_FILES" | wc -l | tr -d ' ')
    echo "Found $TOTAL_FILES PCAP file(s)"
    echo ""
    
    # Create results directory
    RESULTS_DIR="$SCRIPT_DIR/dns_analysis_results"
    mkdir -p "$RESULTS_DIR"
    
    # Summary variables
    PASSED=0
    FAILED=0
    WARNINGS=0
    OUTPUT_FILES_CREATED=0
    
    # Process each file
    FILE_NUM=0
    while IFS= read -r pcap_file; do
        FILE_NUM=$((FILE_NUM + 1))
        filename=$(basename "$pcap_file")
        
        echo -e "${BLUE}[$FILE_NUM/$TOTAL_FILES] Processing: $filename${NC}"
        echo "-------------------------------------------------------------------"
        
        # Create output file for unmatched queries in batch mode
        BATCH_OUTPUT="$RESULTS_DIR/${filename%.pcap}_unmatched.pcap"
        
        # Run the processing function and capture result
        set +e
        if [ "$VERY_VERBOSE" -eq 1 ] || [ "$VERBOSE" -eq 1 ]; then
            process_pcap_file "$pcap_file" "$BATCH_OUTPUT"
            EXIT_CODE=$?
            # Check if output file was created in verbose mode
            if [ -f "$BATCH_OUTPUT" ]; then
                OUTPUT_FILES_CREATED=$((OUTPUT_FILES_CREATED + 1))
            fi
            # Count results in verbose mode
            if [ "$EXIT_CODE" -eq 0 ]; then
                PASSED=$((PASSED + 1))
            elif [ "$EXIT_CODE" -eq 128 ]; then
                FAILED=$((FAILED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
        else
            PROC_OUTPUT=$(process_pcap_file "$pcap_file" "$BATCH_OUTPUT" 2>&1)
            EXIT_CODE=$?
            
            # Check if no packets were found
            if [ "$EXIT_CODE" -eq 0 ] && echo "$PROC_OUTPUT" | grep -q "Total Queries:        0"; then
                echo -e "${YELLOW}WARNING: No packets found in specified time window${NC}"
                WARNINGS=$((WARNINGS + 1))
            elif [ "$EXIT_CODE" -eq 0 ]; then
                PASSED=$((PASSED + 1))
                echo -e "${GREEN}PASSED${NC}"
            elif [ "$EXIT_CODE" -eq 128 ]; then
                FAILED=$((FAILED + 1))
                if [ -f "$BATCH_OUTPUT" ]; then
                    echo -e "${RED}FAILED - See $BATCH_OUTPUT${NC}"
                    OUTPUT_FILES_CREATED=$((OUTPUT_FILES_CREATED + 1))
                else
                    echo -e "${RED}FAILED${NC}"
                fi
            else
                FAILED=$((FAILED + 1))
                echo -e "${RED}FAILED (error code: $EXIT_CODE)${NC}"
            fi
        fi
        set -e
        
        echo ""
    done <<< "$PCAP_FILES"
    
    # Final summary
    echo "==================================================================="
    echo -e "${BLUE}=== Final Summary ===${NC}"
    echo "Total files analyzed: $TOTAL_FILES"
    echo -e "Passed:               ${GREEN}${PASSED}${NC}"
    echo -e "Failed:               ${RED}${FAILED}${NC}"
    if [ "$WARNINGS" -gt 0 ]; then
        echo -e "Warnings:             ${YELLOW}${WARNINGS}${NC}"
    fi
    echo ""
    if [ "$OUTPUT_FILES_CREATED" -gt 0 ]; then
        echo "Results saved to: $RESULTS_DIR"
    fi
    
    if [ "$FAILED" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
else
    # Single file mode
    process_pcap_file "$PCAP_FILE" "$OUTPUT_FILE"
    exit $?
fi

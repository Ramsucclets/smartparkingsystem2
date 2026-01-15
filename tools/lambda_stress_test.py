"""
Lambda Stress Test Script
Tests the parking API endpoint for performance and reliability.

Usage:
    python lambda_stress_test.py [--concurrent N] [--requests N] [--test-type all|get|post]

Requirements:
    pip install aiohttp
"""

import asyncio
import aiohttp
import time
import argparse
import json
import statistics
from datetime import datetime
from dataclasses import dataclass
from typing import List

# Configuration
API_URL = "https://0d3kse1la3.execute-api.us-east-1.amazonaws.com/dev/parking"
COLD_START_THRESHOLD_MS = 500

@dataclass
class RequestResult:
    success: bool
    status_code: int
    latency_ms: float
    error: str = ""
    is_cold_start: bool = False


async def make_get_request(session: aiohttp.ClientSession) -> RequestResult:
    """Make a GET request to fetch all parking spots."""
    start = time.perf_counter()
    try:
        async with session.get(API_URL) as response:
            await response.text()
            latency = (time.perf_counter() - start) * 1000
            return RequestResult(
                success=response.status == 200,
                status_code=response.status,
                latency_ms=latency,
                is_cold_start=latency > COLD_START_THRESHOLD_MS
            )
    except Exception as e:
        latency = (time.perf_counter() - start) * 1000
        return RequestResult(
            success=False,
            status_code=0,
            latency_ms=latency,
            error=str(e)
        )


async def make_post_request(session: aiohttp.ClientSession, spot_id: str) -> RequestResult:
    """Make a POST request to update a parking spot."""
    start = time.perf_counter()
    payload = {
        "spotId": spot_id,
        "status": "Available" if int(spot_id.split("-")[-1]) % 2 == 0 else "Taken"
    }
    try:
        async with session.post(API_URL, json=payload) as response:
            await response.text()
            latency = (time.perf_counter() - start) * 1000
            return RequestResult(
                success=response.status == 200,
                status_code=response.status,
                latency_ms=latency,
                is_cold_start=latency > COLD_START_THRESHOLD_MS
            )
    except Exception as e:
        latency = (time.perf_counter() - start) * 1000
        return RequestResult(
            success=False,
            status_code=0,
            latency_ms=latency,
            error=str(e)
        )


async def stress_test_get(concurrent: int, total: int) -> List[RequestResult]:
    """Run GET stress test."""
    print(f"\n{'-'*70}")
    print(f"  GET STRESS TEST")
    print(f"  Requests: {total}  |  Concurrency: {concurrent}")
    print(f"{'-'*70}")
    
    semaphore = asyncio.Semaphore(concurrent)
    
    async def bounded_get(session):
        async with semaphore:
            return await make_get_request(session)
    
    connector = aiohttp.TCPConnector(limit=concurrent)
    async with aiohttp.ClientSession(connector=connector) as session:
        start_time = time.perf_counter()
        tasks = [bounded_get(session) for _ in range(total)]
        results = await asyncio.gather(*tasks)
        total_time = time.perf_counter() - start_time
    
    print_results("GET", results, total_time)
    return results


async def stress_test_post(concurrent: int, total: int) -> List[RequestResult]:
    """Run POST stress test."""
    print(f"\n{'-'*70}")
    print(f"  POST STRESS TEST")
    print(f"  Requests: {total}  |  Concurrency: {concurrent}")
    print(f"{'-'*70}")
    
    semaphore = asyncio.Semaphore(concurrent)
    
    async def bounded_post(session, idx):
        async with semaphore:
            spot_id = f"TEST-{idx % 100}"
            return await make_post_request(session, spot_id)
    
    connector = aiohttp.TCPConnector(limit=concurrent)
    async with aiohttp.ClientSession(connector=connector) as session:
        start_time = time.perf_counter()
        tasks = [bounded_post(session, i) for i in range(total)]
        results = await asyncio.gather(*tasks)
        total_time = time.perf_counter() - start_time
    
    print_results("POST", results, total_time)
    return results


def print_results(test_type: str, results: List[RequestResult], total_time: float):
    """Print formatted test results."""
    successful = [r for r in results if r.success]
    failed = [r for r in results if not r.success]
    cold_starts = [r for r in results if r.is_cold_start]
    
    latencies = [r.latency_ms for r in successful]
    
    print(f"\n  {test_type} RESULTS")
    print(f"  {'-'*40}")
    print(f"  Total Requests      : {len(results)}")
    print(f"  Successful          : {len(successful)} ({len(successful)/len(results)*100:.1f}%)")
    print(f"  Failed              : {len(failed)}")
    print(f"  Cold Starts (est.)  : {len(cold_starts)} (>{COLD_START_THRESHOLD_MS}ms)")
    print(f"  Total Duration      : {total_time:.2f}s")
    print(f"  Throughput          : {len(results)/total_time:.1f} req/s")
    
    if latencies:
        print(f"\n  LATENCY STATISTICS (ms)")
        print(f"  {'-'*40}")
        print(f"  Minimum             : {min(latencies):.1f}")
        print(f"  Maximum             : {max(latencies):.1f}")
        print(f"  Mean                : {statistics.mean(latencies):.1f}")
        print(f"  Median              : {statistics.median(latencies):.1f}")
        if len(latencies) > 1:
            print(f"  Std Deviation       : {statistics.stdev(latencies):.1f}")
        
        sorted_latencies = sorted(latencies)
        p50 = sorted_latencies[int(len(sorted_latencies) * 0.50)]
        p90 = sorted_latencies[int(len(sorted_latencies) * 0.90)]
        p95 = sorted_latencies[int(len(sorted_latencies) * 0.95)]
        p99 = sorted_latencies[min(int(len(sorted_latencies) * 0.99), len(sorted_latencies)-1)]
        
        print(f"\n  PERCENTILE DISTRIBUTION")
        print(f"  {'-'*40}")
        print(f"  P50                 : {p50:.1f} ms")
        print(f"  P90                 : {p90:.1f} ms")
        print(f"  P95                 : {p95:.1f} ms")
        print(f"  P99                 : {p99:.1f} ms")
    
    if failed:
        print(f"\n  ERRORS")
        print(f"  {'-'*40}")
        error_counts = {}
        for r in failed:
            key = r.error or f"HTTP {r.status_code}"
            error_counts[key] = error_counts.get(key, 0) + 1
        for error, count in error_counts.items():
            print(f"  {error}: {count}")


async def run_ramp_test(max_concurrent: int, step: int = 10):
    """Gradually increase load to find breaking point."""
    print(f"\n{'='*70}")
    print(f"  RAMP-UP TEST")
    print(f"  Finding concurrency limits (step: {step}, max: {max_concurrent})")
    print(f"{'='*70}")
    
    for concurrent in range(step, max_concurrent + 1, step):
        print(f"\n  [Phase {concurrent//step}] Testing {concurrent} concurrent requests")
        await stress_test_get(concurrent, concurrent * 2)
        await asyncio.sleep(2)


async def main():
    parser = argparse.ArgumentParser(description='Lambda Stress Test')
    parser.add_argument('--concurrent', '-c', type=int, default=10,
                        help='Number of concurrent requests (default: 10)')
    parser.add_argument('--requests', '-n', type=int, default=100,
                        help='Total number of requests (default: 100)')
    parser.add_argument('--test-type', '-t', choices=['all', 'get', 'post', 'ramp'],
                        default='all', help='Type of test to run')
    parser.add_argument('--ramp-max', type=int, default=50,
                        help='Max concurrency for ramp test (default: 50)')
    
    args = parser.parse_args()
    
    print(f"""
======================================================================
  LAMBDA STRESS TEST REPORT
  Smart Parking System API
======================================================================
  Endpoint  : {API_URL}
  Timestamp : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
  Test Type : {args.test_type.upper()}
======================================================================""")
    
    if args.test_type in ['all', 'get']:
        await stress_test_get(args.concurrent, args.requests)
    
    if args.test_type in ['all', 'post']:
        await stress_test_post(args.concurrent, args.requests)
    
    if args.test_type == 'ramp':
        await run_ramp_test(args.ramp_max)
    
    print(f"""
======================================================================
  TEST COMPLETE
======================================================================
""")


if __name__ == "__main__":
    asyncio.run(main())

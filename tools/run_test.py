import asyncio
import aiohttp
import time
import statistics
from datetime import datetime

API_URL = "https://0d3kse1la3.execute-api.us-east-1.amazonaws.com/dev/parking"

async def test():
    results = []
    concurrent = 10
    total = 50
    
    semaphore = asyncio.Semaphore(concurrent)
    
    async def make_request(session):
        start = time.perf_counter()
        try:
            async with session.get(API_URL) as response:
                await response.text()
                latency = (time.perf_counter() - start) * 1000
                return {"success": response.status == 200, "latency": latency, "cold": latency > 500}
        except Exception as e:
            return {"success": False, "latency": (time.perf_counter() - start) * 1000, "error": str(e)}
    
    async def bounded(session):
        async with semaphore:
            return await make_request(session)
    
    connector = aiohttp.TCPConnector(limit=concurrent)
    async with aiohttp.ClientSession(connector=connector) as session:
        start_time = time.perf_counter()
        tasks = [bounded(session) for _ in range(total)]
        results = await asyncio.gather(*tasks)
        total_time = time.perf_counter() - start_time
    
    successful = [r for r in results if r.get("success")]
    failed = [r for r in results if not r.get("success")]
    cold = [r for r in results if r.get("cold")]
    latencies = [r["latency"] for r in successful]
    sorted_lat = sorted(latencies)
    
    print("="*70)
    print("  LAMBDA STRESS TEST REPORT")
    print("  Smart Parking System API")
    print("="*70)
    print(f"  Endpoint  : {API_URL}")
    print(f"  Timestamp : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("  Test Type : GET")
    print("="*70)
    print()
    print("-"*70)
    print("  GET STRESS TEST")
    print(f"  Requests: {total}  |  Concurrency: {concurrent}")
    print("-"*70)
    print()
    print("  GET RESULTS")
    print("  " + "-"*40)
    print(f"  Total Requests      : {len(results)}")
    print(f"  Successful          : {len(successful)} ({len(successful)/len(results)*100:.1f}%)")
    print(f"  Failed              : {len(failed)}")
    print(f"  Cold Starts (est.)  : {len(cold)} (>500ms)")
    print(f"  Total Duration      : {total_time:.2f}s")
    print(f"  Throughput          : {len(results)/total_time:.1f} req/s")
    print()
    print("  LATENCY STATISTICS (ms)")
    print("  " + "-"*40)
    print(f"  Minimum             : {min(latencies):.1f}")
    print(f"  Maximum             : {max(latencies):.1f}")
    print(f"  Mean                : {statistics.mean(latencies):.1f}")
    print(f"  Median              : {statistics.median(latencies):.1f}")
    print(f"  Std Deviation       : {statistics.stdev(latencies):.1f}")
    print()
    print("  PERCENTILE DISTRIBUTION")
    print("  " + "-"*40)
    print(f"  P50                 : {sorted_lat[int(len(sorted_lat)*0.50)]:.1f} ms")
    print(f"  P90                 : {sorted_lat[int(len(sorted_lat)*0.90)]:.1f} ms")
    print(f"  P95                 : {sorted_lat[int(len(sorted_lat)*0.95)]:.1f} ms")
    print(f"  P99                 : {sorted_lat[min(int(len(sorted_lat)*0.99), len(sorted_lat)-1)]:.1f} ms")
    print()
    print("="*70)
    print("  TEST COMPLETE")
    print("="*70)

asyncio.run(test())

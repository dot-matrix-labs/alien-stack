# LastStack k6 Benchmarks

This file is the in-repo snapshot of the k6 results that CI also publishes as the `k6-summary/benchmark.md` artifact.

## Current snapshot (placeholder)
| Scenario | VUs | RPS | p95 latency | Notes |
|----------|----:|----:|------------:|-------|
| cold-start smoke | 1 | _pending CI_ | _pending CI_ | CI fills this table |
| saturation | 1000 | _pending CI_ | _pending CI_ | CI fills this table |

## How CI updates this file
- CI runs k6 against the demo server and writes the summary here before uploading `k6-summary/benchmark.md`.
- Keep this file in git so there is always an at-a-glance benchmark snapshot.

## Running k6 locally
Example single-VU smoke:
```bash
k6 run -e TARGET=http://localhost:9090 - <<'EOF'
import http from 'k6/http';
import { check } from 'k6';
export const options = { vus: 1, iterations: 100 };
export default () => {
  const res = http.get(`${__ENV.TARGET || 'http://localhost:9090/'}`);
  check(res, { 'status 200': r => r.status === 200 });
};
EOF
```
Feel free to append your local results below (label with date/commit).

#!/usr/bin/env python3
"""
Plot DiContainer Benchmarks CSV.

Usage:
  python3 Scripts/plot_bench.py --csv bench.csv [--out out_prefix]

CSV format (header required):
  timestamp,debounce_ms,count,total_ms,p50_ms,p95_ms,p99_ms

Requires matplotlib (optional). If not available, prints a text summary.
"""
import argparse, csv, os, sys

def load_csv(path):
    rows = []
    with open(path, newline='') as f:
        reader = csv.DictReader(f)
        for r in reader:
            try:
                rows.append({
                    'ts': r['timestamp'],
                    'debounce': int(r['debounce_ms']),
                    'count': int(r['count']),
                    'total': float(r['total_ms']),
                    'p50': float(r['p50_ms']),
                    'p95': float(r['p95_ms']),
                    'p99': float(r['p99_ms']),
                })
            except Exception as e:
                print('Skip row:', r, e, file=sys.stderr)
    return rows

def group_by_count(rows):
    g = {}
    for r in rows:
        g.setdefault(r['count'], []).append(r)
    for k in g:
        g[k] = sorted(g[k], key=lambda x: x['debounce'])
    return g

def text_summary(groups):
    print('\nText Summary (p95 vs debounce):')
    for cnt, rs in sorted(groups.items()):
        line = f"count={cnt:>9}: " + '  '.join([f"{r['debounce']}ms→{r['p95']:.3f}ms" for r in rs])
        print(line)

def try_plot(groups, out_prefix):
    try:
        import matplotlib.pyplot as plt
    except Exception:
        print('matplotlib not available; skipping PNG plots.\nInstall: pip install matplotlib', file=sys.stderr)
        return

    for cnt, rs in sorted(groups.items()):
        xs = [r['debounce'] for r in rs]
        p50 = [r['p50'] for r in rs]
        p95 = [r['p95'] for r in rs]
        p99 = [r['p99'] for r in rs]
        plt.figure()
        plt.plot(xs, p50, marker='o', label='p50')
        plt.plot(xs, p95, marker='o', label='p95')
        plt.plot(xs, p99, marker='o', label='p99')
        plt.xlabel('Debounce (ms)')
        plt.ylabel('Latency (ms)')
        plt.title(f'Bench p50/p95/p99 — count={cnt}')
        plt.grid(True, alpha=0.3)
        plt.legend()
        out = f"{out_prefix}_count_{cnt}.png"
        plt.savefig(out, dpi=150, bbox_inches='tight')
        plt.close()
        print('Saved', out)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--csv', required=True, help='Benchmarks CSV path')
    ap.add_argument('--out', default='bench', help='Output prefix for PNG files')
    args = ap.parse_args()

    rows = load_csv(args.csv)
    if not rows:
        print('No rows in CSV:', args.csv, file=sys.stderr)
        sys.exit(1)
    groups = group_by_count(rows)
    text_summary(groups)
    try_plot(groups, args.out)

if __name__ == '__main__':
    main()

